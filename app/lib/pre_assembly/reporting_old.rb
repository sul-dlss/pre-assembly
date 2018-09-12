# encoding: UTF-8

module PreAssembly
  module ReportingOld
    def discovery_report(params = {})
      # Runs a confirmation for each digital object and confirms:
      # a) there are no duplicate filenames contained within the object. This is useful if you will be flattening the folder structure during pre-assembly.
      # b) if each object should already be registered, confirms the object exists and has a valid APO
      # c) if using a manifest, confirms that it can locate an object for each entry in the manifest
      # d) if confirm_checksums is true, will open up provided checksum file and confirm each checksum
      # e) if show_staged is true, will show all files that will be staged (warning: will produce a lot of output if you have lots of objects with lots of files!)
      # f) if show_other is true, will show all files/folders in source directory that will NOT be discovered/pre-assembled (warning: will produce a lot of output if you have lots of ignored objects in your directory!)
      # g) if show_smpl_cm is true, will show contentMetadata that will be generated for SMPL objects
      # h) checks that there are no zero size files and that the total object size is greater than 0

      @error_count = 0

      # get user parameters
      no_check_reg = params[:no_check_reg] || false
      check_sourceids = params[:check_sourceids] || false
      confirm_checksums = params[:confirm_checksums] || false
      show_staged = params[:show_staged] || false
      show_other = params[:show_other] || false

      # determine checks to actually be performed, based on user parameters and configuration setings
      using_manifest = @manifest && @object_discovery[:use_manifest]
      using_smpl_manifest = (@content_md_creation[:style] == :smpl) && File.exist?(File.join(@bundle_dir, @content_md_creation[:smpl_manifest]))

      show_smpl_cm = (params[:show_smpl_cm] && using_smpl_manifest) || false

      confirming_checksums = @checksums_file && confirm_checksums
      checking_sourceids = check_sourceids && using_manifest

      confirming_registration = (no_check_reg == false)

      log ""
      log "discovery_report(#{run_log_msg})"

      start_time = Time.now
      puts "\nProject, #{@project_name}"
      puts "Started at #{Time.now}"
      puts "Config filename, #{@config_filename}"
      puts "Directory, #{@bundle_dir}"
      puts "Object discovery via manifest, #{@manifest}" if using_manifest
      puts "Confirming checksums in,#{@checksums_file}" if confirming_checksums
      puts "Checking global uniqueness of source IDs" if checking_sourceids
      puts "Checking APO and registration status" if confirming_registration
      puts "Show all staged files" if show_staged
      puts "Show non-discovered objects in directory" if show_other
      puts "Showing SMPL contentMetadata that will be generated" if show_smpl_cm
      puts "Using SMPL manifest for contentMetadata: #{File.join(@bundle_dir, @content_md_creation[:smpl_manifest])}" if using_smpl_manifest

      if @accession_items
        puts "You are processing specific objects only" if @accession_items[:only]
        puts "You are processing all discovered except for specific objects" if @accession_items[:except]
      end

      header = "\nObject Container , Number of Items , Files with no ext, Files with 0 Size, Total Size, Files Readable , "
      header += "Label , Source ID , " if using_manifest
      header += "Num Files in CM Manifest , All CM files found ," if using_smpl_manifest
      header += "Checksums , " if confirming_checksums
      header += "Duplicate Filenames? , "
      header += "DRUID, Registered? , APO exists? , " if confirming_registration
      header += "SourceID unique in DOR? , " if checking_sourceids
      puts header

      skipped_files = ['Thumbs.db', '.DS_Store'] # if these files are in the bundle directory but not in the manifest, they will be ignorned and not reported as missing
      skipped_files << File.basename(@content_md_creation[:smpl_manifest]) if using_smpl_manifest
      skipped_files << File.basename(@manifest) if using_manifest
      skipped_files << File.basename(@checksums_file) if @checksums_file

      smpl_manifest = PreAssembly::Smpl.new(:csv_filename => @content_md_creation[:smpl_manifest], :bundle_dir => @bundle_dir, :verbose => false) if using_smpl_manifest

      unique_objects = 0
      all_object_containers = manifest_rows.collect { |r| r[@manifest_cols[:object_container]] }
      total_objects = @digital_objects.size
      o2p = objects_to_process

      source_ids = Hash.new(0) # hash to keep track of local source_id uniqueness
      total_size_all_files = 0
      mimetypes = Hash.new(0) # hash to keep track of mimetypes
      counter = 0

      o2p.each do |dobj|
        counter += 1

        bundle_id = File.basename(dobj.unadjusted_container)
        message = "#{counter} of #{o2p.size} : #{bundle_id} , " # obj container id

        if dobj.object_files.count == 0
          message += report_error_message("none") + " N/A ," # no items found and therefore existence gets an N/A
        else
          message += "#{dobj.object_files.count} ," # of items
          total_size = (dobj.object_files.inject(0) { |sum, obj| sum + obj.filesize }) / 1048576.0 # compute total size of all files in this object in MB
          total_size_all_files += total_size # keep running tally of sizes of all discovered files
          dobj.object_files.each { |obj| mimetypes[obj.mimetype] += 1 } # keep a running tally of number of files by mimetype
          filenames_with_no_extension = dobj.object_files.any? { |obj| File.extname(obj.path).empty? }
          file_with_zero_size = dobj.object_files.collect { |obj| obj.filesize == 0 }.include?(true)
          message += (filenames_with_no_extension ? report_error_message("filenames have no extension") : " no , ")
          message += (file_with_zero_size ? report_error_message("a file has zero size") : " no , ")
          message += (total_size == 0 ? report_error_message("object is zero size") : " %.3f" % total_size.to_s + " MB , ") # total size of all files in MB
          message += dobj.object_files_exist? ? ' yes ,' : report_error_message('missing or non-readable files') # check if all files exist and are readable
        end

        # if we are using a manifest, let's add label and source ID from manifest to the report
        message += "\"#{dobj.label}\" , \"#{dobj.source_id}\" ," if using_manifest

        if using_smpl_manifest # if we are using a SMPL manifest, let's add how many files were found
          cm_files = smpl_manifest.manifest[bundle_id]
          num_files_in_manifest = (cm_files && cm_files[:files]) ? cm_files[:files].size : 0
          message += (num_files_in_manifest == 0 ? report_error_message(" no files in CM manifest") : " #{num_files_in_manifest} ,")
          if num_files_in_manifest > 0
            found_files = 0
            all_staged_files = dobj.object_files.collect { |objfile| objfile.relative_path }
            cm_files[:files].each do |file|
              found_files += 1 if all_staged_files.include?(file[:filename])
            end
            message += (num_files_in_manifest != found_files ? report_error_message(" not all files in CM manifest found in object ") : " all files found ,")
          end
        end

        message += confirm_checksums(dobj) ? " confirmed , " : report_error_message("failed") if confirming_checksums # checksum confirmation

        message += (object_filenames_unique?(dobj) ? " no ," : report_error_message("dupes")) # check for dupe filenames, important in a nested object that will be flattened

        source_ids[dobj.source_id] += 1 # keep track of source_id uniqueness

        if confirming_registration # objects should already be registered, let's confirm that
          pid = dobj.pid
          druid = pid.include?('druid') ? pid : "druid:#{pid}"
          message += "#{druid} , "
          begin
            obj = Dor::Item.find(druid)
            message += " yes , " # obj exists
          rescue
            message += report_error_message("no obj") # object does not exist
          end
          begin # if object exists
            apo = obj.admin_policy_object
            message += (apo.nil? ? report_error_message("APO might not exist") : "yes") # check for apo
          rescue # object doesn't exist or checking for apo fails
            message += report_error_message("no APO") # no object, so no APO
          end # end if object exists
        end # end confirming registration

        puts message

        if show_staged # let's show all files that will be staged
          dobj.object_files.each do |objfile|
            puts "-- #{objfile.relative_path}"
          end
        end

        puts smpl_manifest.generate_cm(bundle_id) if show_smpl_cm # let's show SMPL CM
      end

      # now check all files in the bundle directory against the manifest to report on files not referenced
      if using_manifest && show_other && entries_in_bundle_directory.size > 0
        puts "\nExtra Files/Dir Report (items in bundle directory not in manifest, except manifest itself and checksum file):"
        entries_in_bundle_directory.each { |dir_item| puts "* #{dir_item}" unless (all_object_containers.include?(dir_item.to_s.strip) || skipped_files.include?(dir_item.to_s.strip) || dir_item.to_s.strip[0..1] == '._') }
      end

      puts "\nConfig filename, #{@config_filename}"
      puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time) / 60.0)} minutes"
      puts "\nTotal Objects that will be Processed, #{o2p.size}"
      puts "Total Files and Folders in bundle directory, #{entries_in_bundle_directory.count}"
      puts "Total Discovered Objects, #{total_objects}"
      puts "Total Size of all discovered objects, " + "%.3f" % total_size_all_files.to_s + " MB"
      puts "Total Number of files by mimetype in all discovered objects:"
      mimetypes.each do |mimetype, num|
        puts "#{mimetype} , #{num}"
      end

      if using_manifest && !@manifest_cols[:source_id].blank? && manifest_rows.first.methods.include?(@manifest_cols[:source_id])
        if manifest_sourceids_unique?
          puts "All source IDs locally unique: yes"
        else
          source_ids.each { |k, v| puts report_error_message("sourceid \"#{k}\" appears #{v} times") if v.to_i != 1 }
        end
      elsif !using_manifest
        if show_other && (entries_in_bundle_directory.count != total_objects)
          puts "List of entries in bundle directory that will not be discovered: "
          puts (entries_in_bundle_directory - @digital_objects.map(&:container_basename)).join("\n")
        end
      end

      puts "** TOTAL ERRORS FOUND **: #{@error_count}" unless @error_count == 0
    end
  end
end
