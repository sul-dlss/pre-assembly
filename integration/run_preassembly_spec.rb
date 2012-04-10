describe "Pre-assembly integration" do

  before(:each) do
    cmf          = Dor::Config.pre_assembly.cm_file_name
    dmf          = Dor::Config.pre_assembly.dm_file_name
    @temp_dir    = Dir.mktmpdir 'integ_test_', 'tmp'
    @exp_n_files = 3
    @rumsey_dir  = 'spec/test_data/bundle_input_b' 

    @exp_file_patterns = [
      "#{@temp_dir}/**/*.tif",
      "#{@temp_dir}/**/#{cmf}",
      "#{@temp_dir}/**/#{dmf}",
    ]
  end

  def setup_bundle(custom_params = {})
    yaml = YAML.load_file "#{PRE_ASSEMBLY_ROOT}/config/projects/local_dev_revs.yaml"
    @params = PreAssembly::Bundle.symbolize_keys yaml
    @params.merge! custom_params
    @params[:staging_dir]    = @temp_dir
    @params[:show_progress]  = false
    @b = PreAssembly::Bundle.new @params
  end

  describe "Revs-style project" do

    it "should run pre-assembly and produce expected files in staging dir" do
      setup_bundle
      @b.run_pre_assembly
      @exp_file_patterns.each do |patt|
        fs = Dir[patt].select { |f| File.file? f }
        fs.size.should == @exp_n_files
      end
    end

  end

  describe "Rumsey-style project" do

    it "should run pre-assembly and produce expected files in staging dir" do
      # TODO: Rumsey integration assertions.
      setup_bundle :bundle_dir => @rumsey_dir, :project_style => 'style_rumsey'
      @b.run_pre_assembly
      # @exp_file_patterns.each do |patt|
      #   fs = Dir[patt].select { |f| File.file? f }
      #   fs.size.should == @exp_n_files
      # end
    end

  end

end
