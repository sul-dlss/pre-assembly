require 'dir_validator'

module PreAssembly

  # This example illustrates how to use DirValidator in a pre-assembly context.
  #
  # Define a module method validate_bundle_directory() that takes the
  # path to the pre-assembly bundle directory.
  #
  # Inside the method, create a DirValidator and write the validation code.
  #
  # This method should return the validator.
  def self.validate_bundle_directory(bdir)
    dv = DirValidator.new(bdir)
    druid_re = /[a-z]{2} \d{3} [a-z]{2} \d{4}/x
    dv.dirs('druid_dirs', :re => druid_re).each do |d|
      d.file('tifs',   :re   => /^\d+.tif$/)
      d.file('descMD', :name => 'descMetadata.xml')
    end
    dv
  end

end

