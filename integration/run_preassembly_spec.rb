describe "Pre-assembly integration" do

  before(:each) do
    cmf          = Dor::Config.pre_assembly.cm_file_name
    dmf          = Dor::Config.pre_assembly.dm_file_name
    @temp_dir    = Dir.mktmpdir 'integ_test_', 'tmp'
    @exp_n_files = 3

    @exp_file_patterns = [
      "#{@temp_dir}/**/*.tif",
      "#{@temp_dir}/**/#{cmf}",
      "#{@temp_dir}/**/#{dmf}",
    ]

    @params = YAML.load_file "#{PRE_ASSEMBLY_ROOT}/config/projects/local_dev_revs.yaml"
    @params[:staging_dir] = @temp_dir

    @b = PreAssembly::Bundle.new @params
  end

  it "can run pre_assembly and produce expected files in staging dir" do
    lambda { @b.run_pre_assembly }.should_not raise_error
    @exp_file_patterns.each do |patt|
      fs = Dir[patt].select { |f| File.file? f }
      fs.size.should == @exp_n_files
    end
  end

end
