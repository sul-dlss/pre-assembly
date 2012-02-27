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


  describe "initialize() and other setup" do

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


  describe "load_exp_checksums()" do

    it "empty string yields no checksums" do
      @b.stub(:read_exp_checksums).and_return('')
      @b.load_exp_checksums
      @b.exp_checksums.should == {}
    end

    it "checksums are parsed correctly" do
      checksum_data = {
        'foo1.tif' => '4e3cd24dd79f3ec91622d9f8e5ab5afa',
        'foo2.tif' => '7e40beb08d646044529b9138a5f1c796',
        'foo3.tif' => 'e5263af3ebb27d4ab44f70317cb249c1',
        'foo4.tif' => '15263af3ebb27d4ab44f74316cb249a4',
      }
      checksum_string = checksum_data.map { |f,c| "MD5 (#{f}) = #{c}\n" }.join ''
      @b.stub(:read_exp_checksums).and_return(checksum_string)
      @b.load_exp_checksums
      @b.exp_checksums.should == checksum_data
    end

  end


  describe "load_manifest()" do

    it "generates the correct number of digital objects" do
      csv_params = {:sourceid => '', :label => '', :filename => ''}
      csv_rows = (1..4).map { double('csv_row', csv_params) }
      @b.stub(:parse_manifest).and_return(csv_rows)
      @b.load_manifest
      @b.digital_objects.should have(csv_rows.size).items
    end

  end

end
