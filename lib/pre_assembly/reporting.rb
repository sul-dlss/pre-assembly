module PreAssembly

  module Reporting
      
    def discovery_report(params={})
      # Runs a confirmation for each digital object and confirms:
      # a) there are no duplicate filenames contained within the object. This is useful if you will be flattening the folder structure during pre-assembly.
      # b) if each object should already be registered, confirms the object exists and has a valid APO
      # c) if using a manifest, confirms that it can locate an object for each entry in the manifest
      # d) if confirm_checksums is true, will open up provided checksum file and confirm each checksum

      check_sourceids=params[:check_sourceids] || false
      check_reg=params[:check_reg] || false
      confirm_checksums=params[:confirm_checksums] || false
      
      log ""
      log "discovery_report(#{run_log_msg})"
      puts "\nProject, #{@project_name}"
      puts "Directory, #{@bundle_dir}"
      puts "Object discovery via manifest, #{@manifest}" if @manifest && @object_discovery[:use_manifest]
      puts "Confirming checksums in,#{@checksums_file}" if @checksums_file && confirm_checksums
      puts "Checking global uniqueness of source IDs" if check_sourceids && @manifest && @object_discovery[:use_manifest] 
      puts "Checking APO and registration status" if check_reg && @project_style[:should_register] == false
      if @accession_items        
        puts "NOTE: reaccessioning with object cleanup" if @accession_items[:reaccession]
        puts "You are processing specific objects only" if @accession_items[:only]
        puts "You are processing all discovered except for specific objects" if @accession_items[:except]
      end
      
      header="\nObject Container , Number of Items , "
      header+="All Files Exist, Label , Source ID ," if @manifest && @object_discovery[:use_manifest]
      header+="Checksums , " if @checksums_file && confirm_checksums
      header+="Duplicate Filenames? , " unless @manifest && @object_discovery[:use_manifest]
      header+="Registered? , APOs ," if @project_style[:should_register] == false && check_reg
      header+="SourceID unique in DOR? , " if @manifest && @object_discovery[:use_manifest] && check_sourceids
      puts header
      
      unique_objects=0
      @error_count=0
      discover_objects
      load_provider_checksums if @checksums_file && confirm_checksums
      process_manifest

      objects_in_bundle_directory=@digital_objects.collect {|dobj| dobj.container_basename}
      all_object_containers=manifest_rows.collect {|r| r.send(@manifest_cols[:object_container])}

      total_objects=@digital_objects.size

      o2p = objects_to_process
      total_objects_to_process=o2p.size
      source_ids=Hash.new(0)
      
      o2p.each do |dobj|
         bundle_id=File.basename(dobj.unadjusted_container)
         message="#{bundle_id} , " # obj container
         message+= (dobj.object_files.count == 0 ? report_error_message("none") : "#{dobj.object_files.count} ,")  # of items
         
         if @manifest && @object_discovery[:use_manifest] # if we are using a manifest, let's check to see if the file referenced exists
           message += (object_files_exist?(dobj) ? " yes ," : report_error_message("missing files")) # all files exist
           message += "\"#{dobj.label}\" ," # label
           message += "\"#{dobj.source_id}\" ," # source ID
         end
         
         message += confirm_checksums(dobj) ? " confirmed , " : report_error_message("failed") if @checksums_file && confirm_checksums # checksum confirmation
             
         unless @manifest && @object_discovery[:use_manifest]
           is_unique=object_filenames_unique?(dobj)
           unique_objects+=1 if is_unique
           message += (is_unique ? " no ," : report_error_message("dupes")) # dupe filenames
         else
           source_ids[dobj.source_id] += 1
         end
         
         if @project_style[:should_register] == false && check_reg # objects should already be registered, let's confirm that
           druid = bundle_id.include?('druid') ? bundle_id : "druid:#{bundle_id}"
           begin
             obj = Dor::Item.find(druid)
             message += " yes , "
             apos=obj.admin_policy_object_ids.size
             message += (apos == 0 ? report_error_message("no APO") : "#{apos.to_s} ,") # registered and apo
           rescue
             message += report_error_message("no obj") + report_error_message("no APO")
           end
         end

         if @manifest && @object_discovery[:use_manifest] && check_sourceids # let's check for source ID uniqueness
           message += (PreAssembly::Utils.get_druids_by_sourceid(dobj.source_id).size == 0 ? " yes , " : report_error_message("**DUPLICATE**"))
         end
         
         puts message
         
      end
      
      # now check all files in the bundle directory against the manifest to report on files not referenced
      if @manifest && @object_discovery[:use_manifest]
        puts "\nExtra Files/Dir Report (items in bundle directory not in manifest):"
        entries_in_bundle_directory.each do |dir_item|
          puts "** #{dir_item}" unless all_object_containers.include?(dir_item)
        end
      end
      
      puts "\nTotal Objects that will be Processed, #{total_objects_to_process}"
      puts "Total Discovered Objects, #{total_objects}"
      puts "Total Files and Folders in bundle directory, #{entries_in_bundle_directory.count}"

      unless @manifest && @object_discovery[:use_manifest]
        if entries_in_bundle_directory.count != total_objects
          puts "List of entries in bundle directory that will not be discovered: " 
          puts (entries_in_bundle_directory - objects_in_bundle_directory).join("\n")
        end
        puts "\nObjects with non unique filenames, #{total_objects_to_process - unique_objects}"
      else
        if manifest_sourceids_unique?
          puts "All source IDs locally unique: yes"
        else
          source_ids.each {|k, v| puts report_error_message("sourceid \"#{k}\" appears #{v} times") if v.to_i != 1}
        end
      end
      puts "** TOTAL ERRORS FOUND **: #{@error_count}" unless @error_count==0

    end
  
  end

end