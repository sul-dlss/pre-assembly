describe "Pre-assembly integration" do

  # The integration tests.
  # All of the work happens elsewhere.
  it "Revs" do
    run_integration_tests 'revs'
  end

  it "Rumsey" do
    run_integration_tests 'rumsey'
  end

  it "ReidDennis" do
    run_integration_tests 'reid_dennis'
  end


  def run_integration_tests(proj)
    # Setup the bundle for a project and run pre-assembly.
    setup_bundle proj
    @pids = @b.run_pre_assembly
    determine_staged_druid_trees

    # Run checks.
    check_n_of_objects
    check_for_expected_files
    check_dor_objects
  end


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
    conf           = Dor::Config.pre_assembly
    @n_objects     = 3
    @exp_files     = ['*.tif', conf.content_md_file, conf.desc_md_file]
  end

  def determine_staged_druid_trees
    # Determine the druid tree paths in the staging directory.
    @druid_trees = @pids.map { |pid| Druid.new(pid).path(@temp_dir) }
  end


  def check_n_of_objects
    # Did we get the expected N of staged objects?
    @pids.size.should == @n_objects
  end

  def check_for_expected_files
    # Make sure the files were staged as we expected.
    @druid_trees.each do |dt|
      @exp_files.each do |ef|
        glob = File.join dt, ef
        fs   = Dir[glob]
        fs.size.should == 1
      end
    end
  end

  def check_dor_objects
    # Make sure we can get the object from Dor.
    # Skip test for projects not registered by pre-assembly.
    return unless @b.project_style[:should_register]
    @pids.each do |pid|
      item = Dor::Item.find pid
      item.should be_kind_of Dor::Item
    end
  end

end
