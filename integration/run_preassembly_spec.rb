describe "Pre-assembly integration" do

  ####
  # Invoke the Rspec tests.
  ####

  PROJECTS = [
    'revs',
    'rumsey',
    'reid_dennis',
    'gould',
    'sohp',
  ]

  PROJECTS.each do |p|
    it(p) { run_integration_tests p }
  end


  ####
  # Define expectations for the projects.
  ####

  before(:all) do
    conf = Dor::Config.pre_assembly
    @expected  = {
      :revs => {
        :n_objects => 3,
        :exp_files => [
          [1, '*.tif'],
          [1, conf.content_md_file],
          [1, conf.desc_md_file],
        ],
      },
      :gould => {
        :n_objects => 3,
        :exp_files => [
          [3, '00/*.jpg'],
          [1, conf.content_md_file],
        ],
      },
      :sohp => {
        :n_objects => 2,
        :exp_files => [
          [2, '*.jpg'],
          [2, '*.jpg.md5'],
          [2, '*_pm.wav'],
          [2, '*_pm.wav.md5'],
          [2, '*_sh.wav'],
          [2, '*_sh.wav.md5'],
          [2, '*_sl.mp3'],
          [2, '*_sl.mp3.md5'],
          [2, '*_sl_techmd.xml'],
          [1, '*.pdf'],
          [1, '*.pdf.md5'],
          [1, conf.content_md_file],
        ],
      },
    }
    @expected[:rumsey]      = @expected[:revs]
    @expected[:reid_dennis] = @expected[:revs]
  end


  ####
  # Execute the checks.
  ####

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


  ####
  # Setup the project-specific bundle and expectations.
  ####

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
    exp        = @expected[proj.to_sym]
    @n_objects = exp[:n_objects]
    @exp_files = exp[:exp_files]
  end

  def determine_staged_druid_trees
    # Determine the druid tree paths in the staging directory.
    @druid_trees = @pids.map { |pid| Druid.new(pid).path(@temp_dir) }
  end


  ####
  # The checks.
  ####

  def check_n_of_objects
    # Did we get the expected N of staged objects?
    @pids.size.should == @n_objects
  end

  def check_for_expected_files
    # Make sure the files were staged as we expected.
    @druid_trees.each do |dt|
      @exp_files.each do |n, ef|
        glob = File.join dt, ef
        fs   = Dir[glob]
        fs.size.should == n
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
