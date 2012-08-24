describe "Pre-assembly integration" do

  ####
  # Invoke the Rspec tests.
  ####

  PROJECTS = [
    'revs',
    'revs_old_druid_style',
    'revs_no_contentMetadata',
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
    @expected  = {
      :revs => {
        :n_objects => 3,
        :exp_files => [
          [1, 'content/*.tif'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
          [1, "metadata/#{Assembly::DESC_MD_FILE}"],
        ],
      },
      :revs_old_druid_style => {
        :n_objects => 3,
        :exp_files => [
          [1, '*.tif'],
          [1, "#{Assembly::CONTENT_MD_FILE}"],
          [1, "#{Assembly::DESC_MD_FILE}"],
        ],
      },  
      :revs_no_contentMetadata => {
        :n_objects => 3,
        :exp_files => [
          [1, '*.tif'],
          [0, "#{Assembly::CONTENT_MD_FILE}"],
          [1, "#{Assembly::DESC_MD_FILE}"],
        ],
      },          
      :gould => {
        :n_objects => 3,
        :exp_files => [
          [3, 'content/00/*.jpg'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
        ],
      },
      :sohp => {
        :n_objects => 2,
        :exp_files => [
          [2, 'content/*.jpg'],
          [2, 'content/*.jpg.md5'],
          [2, 'content/*_pm.wav'],
          [2, 'content/*_pm.wav.md5'],
          [2, 'content/*_sh.wav'],
          [2, 'content/*_sh.wav.md5'],
          [2, 'content/*_sl.mp3'],
          [2, 'content/*_sl.mp3.md5'],
          [2, 'content/*_sl_techmd.xml'],
          [1, 'content/*.pdf'],
          [1, 'content/*.pdf.md5'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
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
    determine_staged_druid_trees(@b.new_druid_tree_format)

    # Run checks.
    check_n_of_objects
    check_for_expected_files
    check_dor_objects
    cleanup_dor_objects
  
  end


  ####
  # Setup the project-specific bundle and expectations.
  ####

  def setup_bundle(proj)
    # Load the project's YAML config file.
    yaml_file = "#{PRE_ASSEMBLY_ROOT}/spec/test_data/project_config_files/local_dev_#{proj}.yaml"
    yaml      = YAML.load_file yaml_file
    @params   = Assembly::Utils.symbolize_keys yaml
  
    # Create a temp dir to serve as the staging area.
    @temp_dir = Dir.mktmpdir "#{proj}_integ_test_", 'tmp'

    # Override some params.
    @params[:staging_dir]   = @temp_dir
    @params[:show_progress] = false
    @params[:cleanup] = false

    # Create the bundle.
    @b = PreAssembly::Bundle.new @params

    # Set values needed for assertions.
    exp        = @expected[proj.to_sym]
    @n_objects = exp[:n_objects]
    @exp_files = exp[:exp_files]
  end

  def determine_staged_druid_trees(new_druid_tree_format)
    # Determine the druid tree paths in the staging directory.
    if new_druid_tree_format
      @druid_trees = @pids.map { |pid| DruidTools::Druid.new(pid,@temp_dir).path() }
    else
      @druid_trees = @pids.map { |pid| Assembly::Utils.get_staging_path(pid,@temp_dir) }        
    end
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

  def cleanup_dor_objects
    return unless @b.project_style[:should_register]
    @pids.each do |pid| 
      Assembly::Utils.unregister(pid)
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
