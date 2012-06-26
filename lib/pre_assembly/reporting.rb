module PreAssembly

  module Reporting
      
    def discovery_report(params={})
      # Runs a confirmation for each digital object and confirms:
      # a) there are no duplicate filenames contained within the object. This is useful if you will be flattening the folder structure during pre-assembly.
      # b) if each object should already be registered, confirms the object exists and has a valid APO
      # c) if using a manifest, confirms that it can locate an object for each entry in the manifest
      # d) if confirm_checksums is true, will open up provided checksum file and confirm each checksum

      # get user parameters
      no_check_reg=params[:no_check_reg] || false
      check_sourceids=params[:check_sourceids] || false
      confirm_checksums=params[:confirm_checksums] || false
      
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
      if @accession_items        
        puts "NOTE: reaccessioning with object cleanup" if @accession_items[:reaccession]
        puts "You are processing specific objects only" if @accession_items[:only]
        puts "You are processing all discovered except for specific objects" if @accession_items[:except]
      end
      
      header="\nObject Container , Number of Items , Files Readable , "
      header+="Label , Source ID , " if using_manifest
      header+="Checksums , " if confirming_checksums
      header+="Duplicate Filenames? , "
      header+="DRUID from barcode , " if barcode_project
      header+="Registered? , APOs , " if confirming_registration
      header+="SourceID unique in DOR? , " if checking_sourceids
      puts header
      
      unique_objects=0
      @error_count=0
      discover_objects
      load_provider_checksums if confirming_checksums
      process_manifest

      objects_in_bundle_directory=@digital_objects.collect {|dobj| dobj.container_basename}
      all_object_containers=manifest_rows.collect {|r| r.send(@manifest_cols[:object_container])}

      total_objects=@digital_objects.size

      o2p = objects_to_process
      total_objects_to_process=o2p.size
      
      source_ids=Hash.new(0) if using_manifest # hash to keep track of local source_id uniqueness
      
      o2p.each do |dobj|
        
         bundle_id=File.basename(dobj.unadjusted_container)
         message="#{bundle_id} , " # obj container id

         if dobj.object_files.count == 0
           message+=report_error_message("none") + " N/A ," # no items found and therefore existence gets an N/A
         else
           message+="#{dobj.object_files.count} ,"  # of items         
           message += (object_files_exist?(dobj) ? " yes ," : report_error_message("missing or non-readable files")) # check if all files exist and are readable
         end
       
         if using_manifest # if we are using a manifest, let's add label and source ID from manifest to report
           message += "\"#{dobj.label}\" , " # label
           message += "\"#{dobj.source_id}\" ," # source ID
         end
         
         message += confirm_checksums(dobj) ? " confirmed , " : report_error_message("failed") if confirming_checksums # checksum confirmation
             
         message += (object_filenames_unique?(dobj) ? " no ," : report_error_message("dupes")) # check for dupe filenames, important in a nested object that will be flattened

         source_ids[dobj.source_id] += 1 if using_manifest # keep track of source_id uniqueness
         
         if barcode_project # look up druid by container and confirm we can find one
           druid_from_container=dobj.get_pid_from_container_barcode || report_error_message("druid not found")
           message+=" #{druid_from_container} , "
         end
         
         if confirming_registration # objects should already be registered, let's confirm that
           druid = barcode_project ? druid_from_container : (bundle_id.include?('druid') ? bundle_id : "druid:#{bundle_id}")
           begin
             obj = Dor::Item.find(druid)
             message += " yes , "
             apos=obj.admin_policy_object_ids.size
             message += (apos == 0 ? report_error_message("no APO") : "#{apos.to_s} ,") # registered and apo
           rescue
             message += report_error_message("no obj") + report_error_message("no APO")
           end
         end

         if checking_sourceids # let's check for global source ID uniqueness
           message += (Assembly::Utils.get_druids_by_sourceid(dobj.source_id).size == 0 ? " yes , " : report_error_message("**DUPLICATE**"))
         end
         
         puts message
         
      end
      
      # now check all files in the bundle directory against the manifest to report on files not referenced
      if using_manifest
        puts "\nExtra Files/Dir Report (items in bundle directory not in manifest):"
        entries_in_bundle_directory.each { |dir_item| puts "** #{dir_item}" unless all_object_containers.include?(dir_item)}
      end
      
      puts "\nTotal Objects that will be Processed, #{total_objects_to_process}"
      puts "Total Discovered Objects, #{total_objects}"
      puts "Total Files and Folders in bundle directory, #{entries_in_bundle_directory.count}"

      if using_manifest
        if manifest_sourceids_unique?
          puts "All source IDs locally unique: yes"
        else
          source_ids.each {|k, v| puts report_error_message("sourceid \"#{k}\" appears #{v} times") if v.to_i != 1}
        end
      else
        if entries_in_bundle_directory.count != total_objects
          puts "List of entries in bundle directory that will not be discovered: " 
          puts (entries_in_bundle_directory - objects_in_bundle_directory).join("\n")
        end
      end

      puts "** TOTAL ERRORS FOUND **: #{@error_count}" unless @error_count==0

    end
  
  end

end