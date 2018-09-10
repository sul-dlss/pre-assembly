# encoding: UTF-8

module PreAssembly
  module Reporting
    def discovery_report(params = {})
      # Runs a confirmation for each digital object and confirms:
      # a) there are no duplicate filenames contained within the object. This is useful if you will be flattening the folder structure during pre-assembly.
      # b) if each object should already be registered, confirms the object exists and has a valid APO
      # c) manifest: confirms that it can locate an object for each entry in the manifest
      # d) checks that there are no zero size files and that the total object size is greater than 0

      @error_count = 0

      using_smpl_manifest = (content_md_creation[:style] == :smpl) && File.exist?(File.join(bundle_dir, content_md_creation[:smpl_manifest]))

      log ""
      log "discovery_report(#{run_log_msg})"

      start_time = Time.now
      puts "\nProject, #{project_name}"
      puts "Started at #{Time.now}"
      puts "Config filename, #{config_filename}"
      puts "Directory, #{bundle_dir}"
      puts "Object discovery via manifest, #{bundle_context.manifest}"
      puts "Checking APO and registration status"
      puts "Using SMPL manifest for contentMetadata: #{File.join(bundle_dir, content_md_creation[:smpl_manifest])}" if using_smpl_manifest

      # TODO: are we going to support this option in the project yaml?
      if accession_items
        puts "You are processing specific objects only" if accession_items[:only]
        puts "You are processing all discovered except for specific objects" if accession_items[:except]
      end

      header = "\nObject Container , Number of Items , Files with no ext, Files with 0 Size, Total Size, Files Readable , "
      header += "Label , Source ID , "
      header += "Num Files in CM Manifest , All CM files found ," if using_smpl_manifest
      header += "Duplicate Filenames? , "
      header += "DRUID, Registered? , APO exists?"
      puts header

      skipped_files = ['Thumbs.db', '.DS_Store'] # if these files are in the bundle directory but not in the manifest, they will be ignorned and not reported as missing
      skipped_files << File.basename(content_md_creation[:smpl_manifest]) if using_smpl_manifest
      skipped_files << File.basename(bundle_context.manifest)
      skipped_files << File.basename(checksums_file) if checksums_file # TODO: there should never be a checksums file

      smpl_manifest = PreAssembly::Smpl.new(:csv_filename => content_md_creation[:smpl_manifest], :bundle_dir => bundle_dir, :verbose => false) if using_smpl_manifest

      discover_objects
      process_manifest
      total_objects = digital_objects.size

      total_size_all_files = 0
      mimetypes = Hash.new(0) # hash to keep track of mimetypes
      counter = 0

      o2p = objects_to_process
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

        # FIXME: do we want label and sourceid in report?
        message += "\"#{dobj.label}\" , \"#{dobj.source_id}\" ,"

        if using_smpl_manifest
          # report number of files found
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

        message += (object_filenames_unique?(dobj) ? " no , " : report_error_message("dupes")) # check for dupe filenames, important in a nested object that will be flattened

        # confirm objects already registered
        pid = dobj.pid
        druid = pid.include?('druid') ? pid : "druid:#{pid}"
        message += "#{druid} , "
        begin
          obj = Dor::Item.find(druid)
          message += " yes , " # obj exists
        rescue Exception => e
          puts "Error looking up object in DOR: #{e}"
          message += report_error_message("no obj") # object does not exist
        end
        begin
          apo = obj.admin_policy_object
          message += (apo.nil? ? report_error_message("APO might not exist") : "yes") # check for apo
        rescue Exception => e
          # object doesn't exist or checking for apo fails
          puts "Error looking up APO in DOR: #{e}"
          message += report_error_message("no APO")
        end

        puts message
      end

      puts "\nConfig filename, #{config_filename}"
      puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time) / 60.0)} minutes"
      puts "\nTotal Objects that will be Processed, #{o2p.size}"
      puts "Total Files and Folders in bundle directory, #{entries_in_bundle_directory.count}"
      puts "Total Discovered Objects, #{total_objects}"
      puts "Total Size of all discovered objects, " + "%.3f" % total_size_all_files.to_s + " MB"
      puts "Total Number of files by mimetype in all discovered objects:"
      mimetypes.each do |mimetype, num|
        puts "#{mimetype} , #{num}"
      end

      puts "** TOTAL ERRORS FOUND **: #{@error_count}" unless @error_count == 0
    end
  end
end
