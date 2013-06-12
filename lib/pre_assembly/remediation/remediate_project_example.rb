# This is the format of an example project specific remediation.  You must do at least two things:
# DONT EDIT THIS FILE!  Make a copy in your own work area, edit it as needed and pass the full filename to the bin/remediate script.

#  1. The file must be in a module called "RemediationLogic"

#  2. The file must defined a method called "remediate_logic" that defines your specific actions on the Fedora object.


# From within the "remediate_logic" method, you will have access to the Fedora object in the instance variable called @fobj. 
# Just perform the actions you need -- it will be saved out for you.  

# Convenience values avaialble to you:

# @fobj          = the actual Fedora object to operate on
# @pid           = the DRUID (e.g. "druid:oo000oo0001")
# @object_type   = the object type as a symbol,  could be :collection, :item or :adminpolicyobject 

# You an also defined additional methods if you want, and they will be available to you in your remediate_logic method.  To be sure
# you don't conflict with other methods in the base class, you might want to namespace your methods in some way. 

module RemediationLogic
    
    # this method MUST be defined, and should return true or false depending on if remediation should occur
    # if remediation should always occur, just return true
    # but you can also do things like check the object_type and only perform remediations on certain object types
    def should_remediate?
      @object_type == :item  # in this example, we only operate on items
      # return true # or just return true if you always want to operate!
    end
    
    # this method MUST be defined and can peform any action you need to on @fobj    
    def remediate_logic 
    	@fobj.datastreams['rightsMetadata'].content=revs_new_rights_metadata
    end

    # you can add any other methods you might need to access in your 'remediate_logic' method, namespaces the methods your project to prevent any potential clashes with existing methods (e.g. 'revs_do_stuff' instead of just 'do_stuff')
    def revs_new_rights_metadata
      "<newObjectRights>xml goes here</newobjectRights>"
    end
  
end
