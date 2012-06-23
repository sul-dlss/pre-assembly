require 'net/ssh'
require 'csv'

module PreAssembly

  class Utils
    
    # get a list of druids that match the given array of source_ids
    def self.get_druids_by_sourceid(source_ids)
      druids=[]
      source_ids.each {|sid| druids  <<  Dor::SearchService.query_by_id(sid)}
      druids.flatten
    end
    
    def self.robot_status
    
      accession_robots="ps -ef | grep accessionWF | wc -l"
      assembly_robots="ps -ef | grep assemblyWF | wc -l"
      puts "Accession robots are " +  (`#{accession_robots}`.strip.to_i > 3 ? "running" : "NOT running")
      puts "Assembly robots are " +  (`#{assembly_robots}`.strip.to_i > 2 ? "running" : "NOT running")

    end
    
    def self.start_robots
            
      accession_robots="cd /home/lyberadmin/common-accessioning/current; ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ./bin/run_robot start accessionWF:content-metadata accessionWF:descriptive-metadata accessionWF:rights-metadata accessionWF:remediate-object accessionWF:publish accessionWF:shelve accessionWF:provenance-metadata accessionWF:cleanup"
      assembly_robots="cd /home/lyberadmin/assembly/current; ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ./bin/run_robot start assemblyWF:jp2-create assemblyWF:checksum-compute assemblyWF:exif-collect assemblyWF:accessioning-initiate"
      
      puts "To start robots:"
      puts "#{accession_robots}"
      puts "#{assembly_robots}" 

    end
    
    def self.workflow_status(params={})

      druids=params[:druids] || []
      workflows=params[:workflows] || [:assembly]
      filename=params[:filename] || ''

      accession_steps = %w(content-metadata	descriptive-metadata rights-metadata shelve publish)
      assembly_steps = Dor::Config.pre_assembly.assembly_wf_steps.map { |s| s[0] }

      puts "Generating report"

      csv = CSV.open(filename, "w") if filename != ''
      
      header=["druid"]
      header << assembly_steps if workflows.include?(:assembly)
      header << accession_steps if workflows.include?(:accession)
      csv << header.flatten if filename != ''
      puts header.join(',')            
    
      druids.each do |druid|
        output=[druid]
        assembly_steps.each {|step| output << self.get_workflow_status(druid,'assemblyWF',step)} if workflows.include?(:assembly) 
        accession_steps.each {|step| output << self.get_workflow_status(druid,'accessionWF',step)} if workflows.include?(:accession) 
        csv << output if filename != ''
        puts output.join(',')
      end
      
      if filename != ''
        csv.close   
        puts "Report generated in #{filename}"
      end

    end
    
    def self.get_workflow_status(druid,workflow,step)
      begin
        result=Dor::WorkflowService.get_workflow_status('dor', druid, workflow, step)  
      rescue
        result='NOT FOUND'
      end
      return result
    end
    
    ####
     # Cleanup of objects and associated files in specified environment given a list of druids
     ####
     def self.cleanup(params={})
       
       druids=params[:druids] || []
       steps=params[:steps] || []
       dry_run=params[:dry_run] || false
       
       allowed_steps={:stacks=>'This will remove all files from the stacks that were shelved for the objects',
                      :dor=>'This will delete objects from Fedora',
                      :stage=>"This will delete the staged content in #{Dor::Config.pre_assembly.assembly_workspace}",
                      :symlinks=>"This will remove the symlink from #{Dor::Config.pre_assembly.dor_workspace}"}

       num_steps=0

       puts 'THIS IS A DRY RUN' if dry_run

       PreAssembly::Utils.confirm "Run on '#{ENV['ROBOT_ENVIRONMENT']}'? Any response other than 'y' or 'yes' will stop the cleanup now." 
       PreAssembly::Utils.confirm "Are you really sure you want to run on production?  CLEANUP IS NOT REVERSIBLE" if ENV['ROBOT_ENVIRONMENT'] == 'production'

       steps.each do |step|
         if allowed_steps.keys.include?(step)
           PreAssembly::Utils.confirm "Run step '#{step}'?  #{allowed_steps[step]}.  Any response other than 'y' or 'yes' will stop the cleanup now."
           num_steps+=1 # count the valid steps found and agreed to
         end
       end

       raise "no valid steps specified for cleanup" if num_steps == 0
       raise "no druids provided" if druids.size == 0
       
       druids.each {|pid| PreAssembly::Utils.cleanup_object(pid,steps,dry_run)}

    end
     
    def self.cleanup_object(pid,steps,dry_run=false)
      case ENV['ROBOT_ENVIRONMENT']
        when "test"
          stacks_server="stacks-test"
        when "production"
          stacks_server="stacks"
        when "development"
          stacks_server="stacks-dev"
      end
      begin
         # start up an SSH session if we are going to try and remove content from the stacks
         ssh_session=Net::SSH.start(stacks_server,'lyberadmin') if steps.include?(:stacks) && defined?(stacks_server)
        
         druid_tree=Druid.new(pid).tree
         puts "Cleaning up #{pid}"
         if steps.include?(:dor)
           puts "-- deleting #{pid} from Fedora #{ENV['ROBOT_ENVIRONMENT']}" 
           PreAssembly::Utils.unregister(pid) unless dry_run
         end
         if steps.include?(:symlinks)
           path_to_symlink=File.join(Dor::Config.pre_assembly.dor_workspace,druid_tree)
           puts "-- deleting symlink #{path_to_symlink}"
           File.delete(path_to_symlink) if !dry_run && File.exists?(path_to_symlink)
         end
         if steps.include?(:stage)
           path_to_content=File.join(Dor::Config.pre_assembly.assembly_workspace,druid_tree)
           puts "-- deleting folder #{path_to_content}"
           FileUtils.rm_rf path_to_content if !dry_run && File.exists?(path_to_content)
         end
         if steps.include?(:stacks)
           path_to_content=File.join('/stacks',druid_tree)
           puts "-- removing files from the stacks on #{stacks_server} at #{path_to_content}"
           ssh_session.exec!("rm -fr #{path_to_content}") unless dry_run
         end
       rescue Exception => e
         puts "** cleaning up failed for #{pid} with #{e.message}"
       end  
       ssh_session.close if ssh_session
    end
    
    
    def self.delete_from_dor(pid)
      
      Dor::Config.fedora.client["objects/#{pid}"].delete
  
    end
    
    # quicky update rights metadata for any existing objects using default rights metadata pulled from the supplied APO
    def self.update_rights_metadata(druids,apo_druid)
      apo = Dor::Item.find(apo_druid)
      rights_md = apo.datastreams['defaultObjectRights']
      self.replace_datastreams(druids,'rightsMetadata',rights_md.content)
    end
    
    # replace a specific datastream for a series of objects in DOR with new content 
    def self.replace_datastreams(druids,datastream_name,new_content)
      druids.each do |druid|
        obj = Dor::Item.find(druid)
        ds = obj.datastreams[datastream_name]  
        if ds
          ds.content = new_content 
          ds.save
          puts "replaced #{datastream_name} for #{druid}"
        else
          puts "#{datastream_name} does not exist for #{druid}"          
        end
      end 
    end    

    # update a specific datastream for a series of objects in DOR by searching and replacing content 
    def self.update_datastreams(druids,datastream_name,find_content,replace_content)
      druids.each do |druid|
        obj = Dor::Item.find(druid)
        ds = obj.datastreams[datastream_name]
        if ds
          updated_content=ds.content.gsub(find_content,replace_content)  
          ds.content = updated_content
          ds.save
          puts "updated #{datastream_name} for #{druid}"
        else
          puts "#{datastream_name} does not exist for #{druid}"          
        end
      end 
    end    

    
    def self.unregister(pid)
      
      begin
        # Set all assemblyWF steps to error.
        steps = Dor::Config.pre_assembly.assembly_wf_steps
        steps.each { |step, status|  PreAssembly::Utils.set_workflow_step_to_error pid, step }

        # Delete object from Dor.
        PreAssembly::Utils.delete_from_dor pid
        return true
      rescue
        return false
      end
      
    end

    def self.set_workflow_step_to_error(pid, step)
      wf_name = Dor::Config.pre_assembly.assembly_wf
      msg     = 'Integration testing'
      params  =  ['dor', pid, wf_name, step, msg]
      resp    = Dor::WorkflowService.update_workflow_error_status *params
      raise "update_workflow_error_status() returned false." unless resp == true
    end

    def self.clear_stray_workflows
      repo      = 'dor'
      wf        = 'assemblyWF'
      msg       = 'Integration testing'
      wfs       = Dor::WorkflowService
      steps     = Dor::Config.pre_assembly.assembly_wf_steps.map { |s| s[0] }
      completed = steps[0]

      steps.each do |waiting|
        druids = wfs.get_objects_for_workstep completed, waiting, repo, wf
        druids.each do |dru|
          params = [repo, dru, wf, waiting, msg]
          resp = wfs.update_workflow_error_status *params
          puts "updated: resp=#{resp} params=#{params.inspect}"
        end
      end  
    end
    
    def self.reset_workflow_states(params={})
      druids=params[:druids] || []
      steps=params[:steps] || {}
      druids.each do |druid|
      	puts "** #{druid}"
      	begin
      	    steps.each do |workflow,states| 
      	      states.each do |state| 
      	        puts "Updating #{workflow}:#{state} to waiting"
      	        Dor::WorkflowService.update_workflow_status 'dor',druid,workflow, state, 'waiting'
              end
            end
          rescue Exception => e
      		  puts "an error occurred trying to update workflows for #{druid} with message #{e.message}"
      	end
      end
    end
    
    def self.get_druids_from_log(progress_log_file,completed=true)
       druids=[]
       YAML.each_document(PreAssembly::Utils.read_file(progress_log_file)) { |obj| druids << obj[:pid] if obj[:pre_assem_finished] == completed}  
       return druids
    end
    
    def self.load_config(filename)
      YAML.load(PreAssembly::Utils.read_file(filename))  
    end
    
    def self.read_file(filename)
      return File.file?(filename) ? IO.read(filename) : ''
    end
        
    def self.confirm(message)
      puts message
      response=gets.chomp.downcase
      raise "Exiting" if response != 'y' && response != 'yes'
    end

    # used by the completion_report and project_tag_report in the bin directory
    def self.solr_doc_parser(doc,check_status_in_dor=false)
      
      druid = doc[:id]

	    label = doc[:objectLabel_t]
			title=doc[:public_dc_title_t].nil? ? '' : doc[:public_dc_title_t].first
			
			if check_status_in_dor
        accessioned = self.get_workflow_status(druid,'accessionWF','publish')=="completed"
        shelved = self.get_workflow_status(druid,'accessionWF','shelve')=="completed"
			else
  	    accessioned = doc[:wf_wps_facet].nil? ? false : doc[:wf_wps_facet].include?("accessionWF:publish:completed")
  	    shelved = doc[:wf_wps_facet].nil? ? false : doc[:wf_wps_facet].include?("accessionWF:shelve:completed")
      end
	    source_id = doc[:source_id_t]
		  files=doc[:content_file_t]
		  if files.nil?
				file_type_list=""
				num_files=0
			else
		  	num_files = files.size			
				# count the amount of each file type
				file_types=Hash.new(0)
				unless num_files == 0
					files.each {|file| file_types[File.extname(file)]+=1}
					file_type_list=file_types.map{|k,v| "#{k}=#{v}"}.join(' | ')
				end
		  end
		
	    purl_link = ""
	    val = druid.split(/:/).last
	    purl_link = File.join(Dor::Config.purl.base_url, val)
      
      return  [druid, label, title, source_id, accessioned, shelved, purl_link, num_files,file_type_list]   
       
    end

    def self.symbolize_keys(h)
      # Takes a data structure and recursively converts all hash keys from strings to symbols.
      if h.instance_of? Hash
        h.inject({}) { |hh,(k,v)| hh[k.to_sym] = symbolize_keys(v); hh }
      elsif h.instance_of? Array
        h.map { |v| symbolize_keys(v) }
      else
        h
      end
    end

    def self.values_to_symbols!(h)
      # Takes a hash and converts its string values to symbols -- not recursively.
      h.each { |k,v| h[k] = v.to_sym if v.class == String }
    end    
    
  end
  
end
