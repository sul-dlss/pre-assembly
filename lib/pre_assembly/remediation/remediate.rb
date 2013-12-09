module PreAssembly

  module Remediation
    
    class Item
  
      WFS  = Dor::WorkflowService
      REPO = 'dor'
    
      attr_accessor :pid,:fobj,:message,:object_type,:success,:description,:data
      
      def initialize(pid,data=nil)
        @pid=pid
        @data=data
      end
        
      def self.get_druids(progress_log_file,completed=true)
        druids=[]
        if File.readable? progress_log_file 
          YAML.each_document(IO.read(progress_log_file)) { |obj| druids << obj[:pid] if obj[:remediate_completed] == completed}  
        end
        return druids.uniq
      end
      
      # Ensure the log file exists 
      # @param
      # @return
      def ensureLogFile(filename)
        begin
          File.open(filename, 'a') {|f| 
          }
        rescue => e
          raise "Unable to open log file #{filename}: #{e.message}"
        end
      end
      
      # Log to a CSV file
      # @param String csv_out
      # @return
      def log_to_csv(csv_out)
        ensureLogFile(csv_out)
        CSV.open(csv_out, 'a') {|f| 
          output_row=[pid,success,message,Time.now]
          f << output_row
        }
      end
      
      def log_to_progress_file(progress_log_file)
        ensureLogFile(progress_log_file)
        File.open(progress_log_file, 'w+') { |f| 
          f.puts log_info.to_yaml 
        } # complete log to output file
      end
      
      # gets and caches the Dor Item
      def get_object
        @fobj = Dor.find(@pid)
        @object_type=@fobj.class.to_s.gsub('Dor::','').downcase.to_sym  # returns :collection, :item or :adminpolicyobject 
      end
      
      # remediate the object using versioning or not depending on its current state;
      # returns true or false depending on if all steps were successful
      def remediate

        begin
        
          DruidTools::Druid.new(@pid) # this will confirm the druid is valid, if not, we get an exception which is caught below and logged
          get_object  
          
          if should_remediate? # should_remediate? == true              
            
            if versioning_not_required? # object can be updated directly, no versioning needed
              update_object
              @message='remediated directly (versioning not required)' if @success
            elsif in_accessioning? # object in accessioning, cannot be remediated right now
              @success=false
              @message='currently in accessioning, cannot remediate'
            else # object fully ingested, remediate with versioning
              update_object_with_versioning
              @message='remediated with versioning' if @success        
            end
           
           else # should_remediate? == false, no remediation required
           
             @success=true
             @message='remediation not needed'
           
           end
            
        rescue Exception => e  
      
          @success=false
          @message="#{e.message}"
          
        end
        
        return @success
        
      end
      
      # run the update logic but with versioning
      def update_object_with_versioning
        open_version 
        update_object if @success # only continue the process if everything is still good
        close_version if @success # only continue the process if everything is still good
      end
      
      def update_object
        begin
          @success=remediate_logic # this method must be defined for your specific remediation passed in
          if @success
            @fobj.save
            @fobj.publish_metadata
          end
        rescue Exception => e  
          @success=false
          @message="Updating object failed: #{e.message}"
        end
      end
     
     def open_version
       begin # try and open the version
         @fobj.open_new_version
         @fobj.versionMetadata.update_current_version({:description => "auto remeditation #{@description}",:significance => :admin})
         @success=true
       rescue Exception => e  
         if e.message.downcase.include?('already opened')
           @success=true # an already opened version is fine, just proceed as normal
         else
           @success=false
           @message="Opening object failed: #{e.message}"
         end
       end
     end

     def close_version
       begin # try and close the version 
         @fobj.close_version :description => 'automated metadata remediation', :significance => :minor
         @success=true
       rescue Exception => e  
         @success=false
         @message="Closing object failed: #{e.message}"
       end
     end
     
     def log_info
       return {
         :pid                  => @pid,
         :remediate_completed  => @success,
         :message              => @message,
         :timestamp            => Time.now
       }       
     end

    
    def run_assembly_robot(name)
      `ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ~/assembly/current/bin/run_robot run assemblyWF:#{name} -d #{@pid}`
    end

    def run_accession_robot(name)
      `ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ~/common-accessioning/current/bin/run_robot run accessionWF:#{name} -d #{@pid}`
    end
                
     def in_accessioning?
        if Dor::Config.remediation.check_for_in_accessioning
           return (!is_ingested? && !ingest_hold?)
        else
          return false
        end
     end
     
     def versioning_not_required?
       if Dor::Config.remediation.check_for_versioning_required 
         return (!is_ingested? && ingest_hold?) || (!is_ingested? && !is_submitted?)
      else
        return true 
      end
     end   
                   
     # Check if the object is full accessioned and ingested.
     def is_ingested?
       WFS.get_lifecycle(REPO, @pid, 'accessioned') ? true : false
     end

     # Check if the object is on ingest hold
     def ingest_hold?
       # accession2WF is temporary, and anything set to "waiting" in that workflow is really treated like a "hold" condition
       WFS.get_workflow_status(REPO, @pid, 'accessionWF','sdr-ingest-transfer') == 'hold' || (WFS.get_workflow_status(REPO, @pid, 'accession2WF','sdr-ingest-transfer') == 'waiting' && WFS.get_workflow_status(REPO, @pid, 'accessionWF','sdr-ingest-transfer').nil?)
     end

     # Check if the object is submitted
     def is_submitted?
       WFS.get_lifecycle(REPO, @pid, 'submitted') == nil
     end
      
    end

  end

end
