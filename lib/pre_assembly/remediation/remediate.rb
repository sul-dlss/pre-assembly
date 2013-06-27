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
        return druids  
      end
      
      def log_to_csv(csv_out)
        csv_file_out = CSV::Writer.generate(File.open(csv_out,'ab'))
        output_row=[pid,success,message,Time.now]
        csv_file_out << output_row
        csv_file_out.close
      end
      
      def log_to_progress_file(progress_log_file)
        File.open(progress_log_file, 'a') { |f| f.puts log_info.to_yaml } # complete log to output file
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
            
            if (!is_ingested? && ingest_hold?) || (!is_ingested? && !is_submitted?) # object can be updated directly, no versioning needed
              update_object
              @message='remediated directly (versioning not required)' if @success
            elsif (!is_ingested? && !ingest_hold?) # object in accessioning, cannot be remediated right now
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
#            WFS.update_workflow_status(REPO, @pid, 'accessionWF','publish','waiting') # set publish step back to waiting to be sure we republish public XML
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
         @success=false
         @message="Opening object failed: #{e.message}"
       end
     end

     def close_version
       begin # try and close the version and ensure ingest is not on hold
         @fobj.close_version
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
         :timestamp            => Time.now.to_s
       }       
     end

    
    def run_assembly_robot(name)
      `ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ~/assembly/current/bin/run_robot run assemblyWF:#{name} -d #{@pid}`
    end

    def run_accession_robot(name)
      `ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ~/common-accessioning/current/bin/run_robot run accessionWF:#{name} -d #{@pid}`
    end
                
     # Check if the object is full accessioned and ingested.
     def is_ingested?
       WFS.get_lifecycle(REPO, @pid, 'accessioned') ? true : false
     end

     # Check if the object is on ingest hold
     def ingest_hold?
       WFS.get_workflow_status(REPO, @pid, 'accessionWF','sdr-ingest-transfer') == 'hold'
     end

     # Check if the object is submitted
     def is_submitted?
       WFS.get_lifecycle(REPO, @pid, 'submitted') == nil
     end
      
    end

  end

end