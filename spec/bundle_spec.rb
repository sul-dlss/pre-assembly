describe PreAssembly::Bundle do

  before(:all) do
    @yaml = File.read 'config/projects/local_dev_revs.yaml'
  end

  before(:each) do
    @ps = YAML.load @yaml
    @b  = PreAssembly::Bundle.new @ps
  end

  describe "initialize() and other setup" do

    it "can initialize a Bundle" do
      @b.should be_kind_of PreAssembly::Bundle
    end

    it "can exercise the run_log_msg" do
      @b.run_log_msg.should be_kind_of String
    end

  end

  describe "validate_usage()" do

    before(:each) do
      @b.user_params = Hash[ @b.required_user_params.map { |p| [p, ''] } ]
      @exp_err = PreAssembly::BundleUsageError
    end

    it "N of required files should vary by project type" do
      n_exp = {
        :style_revs   => 2,
        :style_rumsey => 0,
      }
      n_exp.each do |style, n| 
        @b.project_style = style
        @b.required_files.should have(n).items
      end
    end

    it "should not raise an exception if requirements are satisfied" do
      @b.validate_usage
    end

    it "should raise exception if a user parameter is missing" do
      @b.user_params.delete :bundle_dir
      exp_msg = /^Missing.+bundle_dir/
      lambda { @b.validate_usage }.should raise_error @exp_err, exp_msg
    end

    it "should raise exception if required directory not found" do
      @b.bundle_dir = '__foo_bundle_dir###'
      exp_msg = /^Required directory.+#{@b.bundle_dir}/
      lambda { @b.validate_usage }.should raise_error @exp_err, exp_msg
    end

    it "should raise exception if required file not found" do
      @b.manifest = '__foo_manifest###'
      exp_msg = /^Required file.+#{@b.manifest}/
      lambda { @b.validate_usage }.should raise_error @exp_err, exp_msg
    end

  end

  describe "object discovery" do
    
    it "object_containers() should dispatch the correct method" do
      exp = {
        :object_containers_via_manifest => true,
        :object_containers_via_crawl    => false,
      }
      exp.each do |meth, use_man|
        @b.object_discovery[:use_manifest] = use_man
        @b.stub meth
        @b.should_receive(meth).exactly(1).times
        @b.discover_objects
      end
    end

    it "object_containers_via_manifest() should return expected information" do
      col_name = :col_foo
      vals     = [123, 456, 789]
      rows     = vals.map { |v| double('row', col_name => v) }
      @b.manifest_cols[:object_container] = col_name
      @b.stub(:manifest_rows).and_return rows
      @b.object_containers_via_manifest.should == vals
    end

    it "object_containers_via_crawl() should return expected information" do
      items = [
        'abc.txt', 'def.txt', 'ghi.txt',
        '123.tif', '456.tif', '456.TIF',
      ]
      items_in_bundle = items.map { |i| @b.full_path_in_bundle_dir i }
      @b.stub(:object_discovery_glob_results).and_return items_in_bundle
      # No regex filtering.
      @b.object_discovery[:regex] = ''
      @b.object_containers_via_crawl.should == items
      # Only tif files.
      @b.object_discovery[:regex] = '(?i)\.tif$'
      @b.object_containers_via_crawl.should == items[3..-1]
    end

    it "object_discovery_glob_results() should return expected information" do
      exp = [1,2,3].map { |n| "#{@b.bundle_dir}/image#{n}.tif" }
      @b.object_discovery[:glob] = '*.tif'
      @b.object_discovery_glob_results.should == exp
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

    before(:all) do
      @syms              = [:sourceid, :label, :filename, :foo, :bar]
      @vals              = @syms.map { |s| s.to_s.upcase }
      @exp_provider_attr = Hash[@syms.zip @vals]
      CsvParams          = Struct.new(*@syms)
    end

    before(:each) do
      @csv_rows = (1..4).map { CsvParams.new(*@vals) }
      @b.stub(:manifest_rows).and_return(@csv_rows)
    end

    it "preserves the provider attributes" do
      @b.load_manifest
      @b.digital_objects[0].images[0].provider_attr.should == @exp_provider_attr
    end

    it "generates the correct number of digital objects" do
      @b.load_manifest
      @b.digital_objects.should have(@csv_rows.size).items
    end

    it "generates the correct number of digital objects when @limit_n is set" do
      n = @csv_rows.size - 1
      @b.limit_n = n
      @b.load_manifest
      @b.digital_objects.should have(n).items
    end

  end

  describe "validate_images()" do

    it "should not raise errors with valid tif files" do
      @b.load_manifest
      lambda { @b.validate_images }.should_not raise_error
    end

    it "should raise error if an invalid tif file is present" do
      @b.load_manifest
      @b.digital_objects[0].images[0].full_path = @b.manifest
      lambda { @b.validate_images }.should raise_error
    end

  end

  describe "source_id_suffix()" do
    
    it "should be empty if we are not asked to make source IDs unique" do
      @b.uniqify_source_ids = false
      @b.source_id_suffix.should == ''
    end

    it "should look like an integer if uniqify_source_ids is true" do
      @b.uniqify_source_ids = true
      @b.source_id_suffix.should =~ /^_\d+$/
    end

  end

  describe "file and directory utilities" do

    before(:each) do
      @relative = 'abc/def.jpg'
      @full     = "#{@b.bundle_dir}/#{@relative}"
    end

    it "full_path_in_bundle_dir() should return expected value" do
      @b.full_path_in_bundle_dir(@relative).should == @full
    end

    it "rel_path_in_bundle_dir() should return expected value" do
      @b.rel_path_in_bundle_dir(@full).should == @relative
    end

  end

end
