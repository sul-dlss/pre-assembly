module PreAssembly

  module Reporting
      
    def discovery_report(params={})
      # Runs a confirmation for each digital object and confirms:
      # a) there are no duplicate filenames contained within the object. This is useful if you will be flattening the folder structure during pre-assembly.
      # b) if each object should already be registered, confirms the object exists and has a valid APO
      # c) if using a manifest, confirms that it can locate an object for each entry in the manifest
      # d) if confirm_checksums is true, will open up provided checksum file and confirm each checksum
      # e) if show_staged is true, will show all files that will be staged (warning: will produce a lot of output if you have lots of objects with lots of files!)
      # f) if show_other is true, will show all files/folders in source directory that will NOT be discovered/pre-assembled (warning: will produce a lot of output if you have lots of ignored objects in your directory!)

      @error_count=0

      # get user parameters
      no_check_reg=params[:no_check_reg] || false
      check_sourceids=params[:check_sourceids] || false
      confirm_checksums=params[:confirm_checksums] || false
      show_staged=params[:show_staged] || false
      show_other=params[:show_other] || false
              
      # determine checks to actually be performed, based on user parameters and configuration setings
      using_manifest=@manifest && @object_discovery[:use_manifest]
      confirming_checksums=@checksums_file && confirm_checksums
      checking_sourceids=check_sourceids && using_manifest

      confirming_registration=(no_check_reg == false && @project_style[:should_register] == false)
      barcode_project=@project_style[:get_druid_from] == :container_barcode
      
      log ""
      log "discovery_report(#{run_log_msg})"
      
      puts "\nProject, #{@project_name}"
      puts "Config filename, #{@config_filename}"
      puts "Directory, #{@bundle_dir}"
      puts "Object discovery via manifest, #{@manifest}" if using_manifest
      puts "Confirming checksums in,#{@checksums_file}" if confirming_checksums
      puts "Checking global uniqueness of source IDs" if checking_sourceids
      puts "Checking APO and registration status" if confirming_registration
      puts "Show all staged files" if show_staged
      puts "Show non-discovered objects in directory" if show_other

      if @accession_items        
        puts "NOTE: reaccessioning with object cleanup" if @accession_items[:reaccession]
        puts "You are processing specific objects only" if @accession_items[:only]
        puts "You are processing all discovered except for specific objects" if @accession_items[:except]
      end
      if @project_style[:should_register] # confirm the supplied APO
        puts report_error_message("Specified APO #{@apo_druid_id} does not exist or the specified object does exist but is not an APO") if Assembly::Utils.is_apo?(@apo_druid_id) == false
      end
      header="\nObject Container , Number of Items , Files Have Spaces, Total Size, Files Readable , "
      header+="Label , Source ID , " if using_manifest
      header+="Checksums , " if confirming_checksums
      header+="Duplicate Filenames? , "
      header+="DRUID, Registered? , APOs , " if confirming_registration
      header+="SourceID unique in DOR? , " if checking_sourceids
      puts header
      
      unique_objects=0
      discover_objects
      load_provider_checksums if confirming_checksums
      process_manifest

      objects_in_bundle_directory=@digital_objects.collect {|dobj| dobj.container_basename}
      all_object_containers=manifest_rows.collect {|r| r.send(@manifest_cols[:object_container])}

      total_objects=@digital_objects.size

      o2p = objects_to_process
      total_objects_to_process=o2p.size
      
      source_ids=Hash.new(0) if using_manifest # hash to keep track of local source_id uniqueness
      total_size_all_files=0
      mimetypes=Hash.new(0) # hash to keep track of mimetypes
      
      o2p.each do |dobj|
        
         bundle_id=File.basename(dobj.unadjusted_container)
         message="#{bundle_id} , " # obj container id

         if dobj.object_files.count == 0
           message+=report_error_message("none") + " N/A ," # no items found and therefore existence gets an N/A
         else
           message+="#{dobj.object_files.count} ,"  # of items   
           total_size=(dobj.object_files.inject(0){|sum,obj| sum+obj.filesize})/1048576.0 # compute total size of all files in this object in MB
           total_size_all_files+=total_size # keep running tally of sizes of all discovered files
           dobj.object_files.each{|obj| mimetypes[obj.mimetype]+=1} # keep a running tally of number of files by mimetype
           filenames_have_spaces=dobj.object_files.collect{|obj| obj.path.include?(' ')}.include?(true)
           message += (filenames_have_spaces ? report_error_message("filenames have spaces") : " no , ") 
           message += " %.3f" % total_size.to_s + " MB , " # total size of all files in MB      
           message += (object_files_exist?(dobj) ? " yes ," : report_error_message("missing or non-readable files")) # check if all files exist and are readable
         end
       
         if using_manifest # if we are using a manifest, let's add label and source ID from manifest to the report
           message += "\"#{dobj.label}\" , " # label
           message += "\"#{dobj.source_id}\" ," # source ID
         end
         
         message += confirm_checksums(dobj) ? " confirmed , " : report_error_message("failed") if confirming_checksums # checksum confirmation
             
         message += (object_filenames_unique?(dobj) ? " no ," : report_error_message("dupes")) # check for dupe filenames, important in a nested object that will be flattened

         source_ids[dobj.source_id] += 1 if using_manifest # keep track of source_id uniqueness
           
         if confirming_registration # objects should already be registered, let's confirm that
           if barcode_project # look up druid by container and confirm we can find one
             druid_from_container=dobj.get_pid_from_container_barcode || report_error_message("druid not found from barcode")
           end
           dobj.determine_druid
           pid = dobj.pid
           druid = pid.include?('druid') ? pid : "druid:#{pid}"
           message += "#{druid} , " 
           begin
             obj = Dor::Item.find(druid)
             message += " yes , " # obj exists
             apos=obj.admin_policy_object_ids
             message += (apos.size == 0 ? report_error_message("no APO") : "#{apos.size}") # apo
           rescue
             message += report_error_message("no obj") + report_error_message("no APO")
           end
         end
           
         if checking_sourceids # let's check for global source ID uniqueness
           message += (Assembly::Utils.get_druids_by_sourceid(dobj.source_id).size == 0 ? " yes , " : report_error_message("**DUPLICATE**"))
         end
         
         puts message
         
         if show_staged # let's show all files that will be staged
           dobj.object_files.each do |objfile|
              puts "-- #{objfile.relative_path}"
           end 
         end
         
      end
      
      # now check all files in the bundle directory against the manifest to report on files not referenced
      if using_manifest && show_other
        puts "\nExtra Files/Dir Report (items in bundle directory not in manifest):"
        entries_in_bundle_directory.each { |dir_item| puts "** #{dir_item}" unless all_object_containers.include?(dir_item)}
      end
      
      puts "\nTotal Objects that will be Processed, #{total_objects_to_process}"
      puts "Total Files and Folders in bundle directory, #{entries_in_bundle_directory.count}"
      puts "Total Discovered Objects, #{total_objects}"
      puts "Total Size of all discovered objects, " + "%.3f" % total_size_all_files.to_s + " MB"
      puts "Total Number of files by mimetype in all discovered objects:"
      mimetypes.each do |mimetype,num|
        puts "#{mimetype} , #{num}"
      end
      
      if using_manifest && !@manifest_cols[:source_id].blank? && manifest_rows.first.methods.include?(@manifest_cols[:source_id])
        if manifest_sourceids_unique?
          puts "All source IDs locally unique: yes"
        else
          source_ids.each {|k, v| puts report_error_message("sourceid \"#{k}\" appears #{v} times") if v.to_i != 1}
        end
      else
        if show_other && (entries_in_bundle_directory.count != total_objects)
          puts "List of entries in bundle directory that will not be discovered: " 
          puts (entries_in_bundle_directory - objects_in_bundle_directory).join("\n")
        end
      end

      puts "** TOTAL ERRORS FOUND **: #{@error_count}" unless @error_count==0

    end
  
  end

end