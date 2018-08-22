ENV['RAILS_ENV'] = 'test'

helper = File.expand_path(File.dirname(__FILE__) + '/../spec/spec_helper')
require helper

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
    'sohp_via_symlink',
    'sohp_discovery_manifest'
  ]

  PROJECTS.each do |p|
    # The Revs Project tests try to register objects during integration tests,
    # and the SURI service tries to make a Fedora connection, breaking the tests.
    # Disable them for now so at least the other integration tests can run -- July 17, 2017 Peter Mangiafico
    if p.match(/(revs)/)
      xit(p)
    else
      it(p) { run_integration_tests p }
    end
  end

  ####
  # Define expectations for the projects.
  ####

  before(:all) do
    @expected = {
      :revs => {
        :n_objects => 3,
        :exp_files => [
          [1, 'content/*.tif'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
          [1, "metadata/#{Assembly::DESC_MD_FILE}"],
          [0, "metadata/#{Assembly::TECHNICAL_MD_FILE}"],
        ],
      },
      :revs_old_druid_style => {
        :n_objects => 3,
        :exp_files => [
          [1, '*.tif'],
          [1, "#{Assembly::CONTENT_MD_FILE}"],
          [1, "#{Assembly::DESC_MD_FILE}"],
          [0, "metadata/#{Assembly::TECHNICAL_MD_FILE}"],
        ],
      },
      :revs_no_contentMetadata => {
        :n_objects => 3,
        :exp_files => [
          [1, '*.tif'],
          [0, "#{Assembly::CONTENT_MD_FILE}"],
          [1, "#{Assembly::DESC_MD_FILE}"],
          [0, "metadata/#{Assembly::TECHNICAL_MD_FILE}"],
        ],
      },
      :gould => {
        :n_objects => 3,
        :exp_files => [
          [3, 'content/00/*.jpg'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
          [0, "metadata/#{Assembly::TECHNICAL_MD_FILE}"],
        ],
      },
      :sohp => {
        :n_objects => 2,
        :exp_files => [
          [2, 'content/*.jpg'],
          [0, 'content/*.jpg.md5'],
          [2, 'content/*_pm.wav'],
          [0, 'content/*_pm.wav.md5'],
          [2, 'content/*_sh.wav'],
          [0, 'content/*_sh.wav.md5'],
          [2, 'content/*_sl.mp3'],
          [0, 'content/*_sl.mp3.md5'],
          [0, 'content/*_sl_techmd.xml'],
          [1, 'content/*.pdf'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
          [1, "metadata/#{Assembly::TECHNICAL_MD_FILE}"],
          [0, "metadata/#{Assembly::DESC_MD_FILE}"],
        ],
      },
      :sohp_discovery_manifest => {
        :n_objects => 1,
        :exp_files => [
          [2, 'content/*.jpg'],
          [0, 'content/*.jpg.md5'],
          [2, 'content/*_pm.wav'],
          [0, 'content/*_pm.wav.md5'],
          [2, 'content/*_sh.wav'],
          [0, 'content/*_sh.wav.md5'],
          [2, 'content/*_sl.mp3'],
          [0, 'content/*_sl.mp3.md5'],
          [0, 'content/*_sl_techmd.xml'],
          [1, 'content/*.pdf'],
          [1, "metadata/#{Assembly::CONTENT_MD_FILE}"],
          [1, "metadata/#{Assembly::TECHNICAL_MD_FILE}"],
          [1, "metadata/#{Assembly::DESC_MD_FILE}"],
        ],
      },
    }
    @expected[:rumsey]      = @expected[:revs]
    @expected[:reid_dennis] = @expected[:revs]
    @expected[:sohp_via_symlink] = @expected[:sohp]
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
    check_descMetadata if proj == 'revs'
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
    @params[:bundle_dir] = File.join(PRE_ASSEMBLY_ROOT, @params[:bundle_dir])
    @params[:validate_bundle_dir][:code] = File.join(PRE_ASSEMBLY_ROOT, @params[:validate_bundle_dir][:code]) if @params[:validate_bundle_dir]
    # Create the bundle.
    @b = PreAssembly::Bundle.new(PreAssembly::BundleContext.new(@params))

    # Set values needed for assertions.
    exp        = @expected[proj.to_sym]
    @n_objects = exp[:n_objects]
    @exp_files = exp[:exp_files]
  end

  def determine_staged_druid_trees(new_druid_tree_format)
    # Determine the druid tree paths in the staging directory.
    if new_druid_tree_format
      @druid_trees = @pids.map { |pid| DruidTools::Druid.new(pid, @temp_dir).path() }
    else
      @druid_trees = @pids.map { |pid| Assembly::Utils.get_staging_path(pid, @temp_dir) }
    end
  end

  ####
  # The checks.
  ####

  # confirm that a descMetadata file looks file as generated by the manifest
  def check_descMetadata
  end

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
end
