Any files included in this directory will be included automatically in the "DigitalObject" class automatically, which is useful if you need
to specific project specific methods for generating content metadata (e.g. for SMPL) or in generating descriptive metadata (e.g. for Revs).

If you name your file "my_project_file.rb", be sure your module name reflects this using the ruby camelized standard, as below:


module PreAssembly

  module Project

    module MyProjectFile

       	def your_cool_methods_here_but_name_them_specific_to_your_project_so_they_dont_clash
				
				end
    
			end
    
  end
  
end