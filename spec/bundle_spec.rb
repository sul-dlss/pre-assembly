describe Assembly::Bundle do

  before(:each) do
    @ps = {
      :bundle_dir      => 'spec/test_data/bundle_input',
      :manifest        => 'manifest.csv',
      :checksums_file  => 'checksums.txt',
      :copy_to_staging => false,
      :staging_dir     => 'tmp',
    }
    @b = Assembly::Bundle.new @ps
  end

  it "can be initialized" do
    @b.should be_kind_of Assembly::Bundle
  end

  it "can set the full path to the bundle directory" do
    @b.full_path_in_bundle_dir('foo.txt').should be_kind_of String
  end

  it "gets the correct stager" do
    @b.copy_to_staging = true
    stager = @b.get_stager
    stager.should equal @b.stagers[:copy]

    @b.copy_to_staging = false
    stager = @b.get_stager
    stager.should equal @b.stagers[:move]
  end

  describe "check_for_required_files()" do

    it "does not raise exception when required files exist" do
      return_vals = @b.required_files.map { true }
      @b.stub(:file_exists).and_return(*return_vals)
      lambda { @b.check_for_required_files }.should_not raise_error
    end

    it "raises an exception when a required file is missing" do
      return_vals = @b.required_files.map { true }
      return_vals[-1] = false
      @b.stub(:file_exists).and_return(*return_vals)
      lambda { @b.check_for_required_files }.should raise_error
    end

  end

end
