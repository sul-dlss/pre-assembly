describe "Pre-assembly integration" do

  def setup_bundle(project_style)
    # Load the project's YAML config file.
    proj      = project_style.to_s.sub /^style_/, ''
    yaml_file = "#{PRE_ASSEMBLY_ROOT}/config/projects/local_dev_#{proj}.yaml"
    yaml      = YAML.load_file yaml_file
    @params   = PreAssembly::Bundle.symbolize_keys yaml
    
    # Create a temp dir to serve as the staging area.
    @temp_dir = Dir.mktmpdir "#{proj}_integ_test_", 'tmp'

    # Override some params.
    @params[:staging_dir]   = @temp_dir
    @params[:show_progress] = false

    # Create the bundle.
    @b = PreAssembly::Bundle.new @params

    # Set values needed for assertions.
    conf         = Dor::Config.pre_assembly
    dru_tree     = "#{@temp_dir}/??/???/??/????"
    @exp_n_files = 3
    @exp_files   = [
      "#{dru_tree}/*.tif",
      "#{dru_tree}/#{conf.cm_file_name}",
      "#{dru_tree}/#{conf.dm_file_name}",
    ]
  end

  def check_for_expected_files
    @exp_files.each do |glob_pattern|
      fs = Dir[glob_pattern].select { |f| File.file? f }
      fs.size.should == @exp_n_files
    end
  end

  describe "Revs-style project" do

    it "should produce expected files in staging dir" do
      setup_bundle :style_revs
      @b.run_pre_assembly
      check_for_expected_files
    end

  end

  describe "Rumsey-style project" do

    it "should produce expected files in staging dir" do
      setup_bundle :style_rumsey
      @b.run_pre_assembly
      check_for_expected_files
    end

  end

end
