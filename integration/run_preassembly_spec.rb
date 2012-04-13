describe "Pre-assembly integration" do

  def setup_bundle(proj)
    # Load the project's YAML config file.
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
    conf       = Dor::Config.pre_assembly
    dru_tree   = "#{@temp_dir}/??/???/??/????"
    @n_objects = 3
    @exp_files = ['*.tif', conf.cm_file_name, conf.dm_file_name]
  end

  def check_for_expected_files
    # Get pids of the process objects and determine the druid tree paths
    # in the staging directory.
    pids        = @b.run_pre_assembly
    druid_trees = pids.map { |pid| Druid.new(pid).path(@temp_dir) }

    # Did we get the expect N of staged objects?
    druid_trees.size.should == @n_objects

    # Make sure the files were staged as we expected.
    druid_trees.each do |dt|
      @exp_files.each do |ef|
        glob = File.join dt, ef
        fs   = Dir[glob]
        fs.size.should == 1
      end
    end

  end

  describe "Revs" do

    it "should produce expected files in staging dir" do
      setup_bundle 'revs'
      check_for_expected_files
    end

  end

  describe "Rumsey" do

    it "should produce expected files in staging dir" do
      setup_bundle 'rumsey'
      check_for_expected_files
    end

  end

  describe "ReidDennis" do

    it "should produce expected files in staging dir" do
      setup_bundle 'reid_dennis'
      check_for_expected_files
    end

  end

end
