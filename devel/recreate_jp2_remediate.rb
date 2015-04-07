require 'fileutils'

module RemediationLogic
    
    # this method MUST be defined, and should return true or false depending on if remediation should occur
    # if remediation should always occur, just return true
    # but you can also do things like check the object_type and only perform remediations on certain object types
    def should_remediate?
      @object_type == :item  # in this example, we only operate on items
      # return true # or just return true if you always want to operate!
    end
    
    # this method MUST be defined and can peform any action you need to on @fobj - YOU MUST RETURN TRUE OR FALSE TO INDICATE SUCCESS  
    def remediate_logic         
      run_assembly_robot('jp2-create')
      run_assembly_robot('exif-collect')
      run_assembly_robot('checksum-compute')
      Dor::WorkflowService.update_workflow_status('dor',@pid,'assemblyWF', 'accessioning-initiate', 'completed')
    end
    
end