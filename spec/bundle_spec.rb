describe PreAssembly::Bundle do

  before(:all) do
    @yaml = {
      :yaml_revs   => File.read('config/projects/local_dev_revs.yaml'),
      :yaml_rumsey => File.read('config/projects/local_dev_rumsey.yaml'),
    }
  end

  def bundle_setup(project_style)
    @ps = YAML.load @yaml[project_style]
    @b  = PreAssembly::Bundle.new @ps
  end


  describe "initialize() and other setup" do

    before(:each) do
      bundle_setup :yaml_revs
    end

    it "can initialize a Bundle" do
      @b.should be_kind_of PreAssembly::Bundle
    end

    it "can exercise the run_log_msg" do
      @b.run_log_msg.should be_kind_of String
    end

  end


  describe "validate_usage()" do

    before(:each) do
      bundle_setup :yaml_revs
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
    
    before(:each) do
      bundle_setup :yaml_revs
    end

    it "discover_objects() should make correct N of digital objects and stageable items" do
      exp = {
        :yaml_revs   => [1,1,1],
        :yaml_rumsey => [2,2,2],
      }
      exp.each do |project_style, n_stageables|
        bundle_setup project_style
        @b.discover_objects
        dobjs = @b.digital_objects

        # Corrent N of items.
        dobjs.should have(n_stageables.size).items
        dobjs.map { |dobj| dobj.stageable_items.size }.should == n_stageables
        
        # Correct handling of digital object container.
        if @b.stageable_discovery[:use_container]
          dobjs[0].container.should == @b.bundle_dir
        else
          dobjs[0].container.should_not == @b.bundle_dir
        end
      end
    end

    it "@pruned_containers should limit N of discovered objects if @limit_n is defined" do
      items = [0,11,22,33,44,55,66,77]
      @b.limit_n = nil
      @b.pruned_containers(items).should == items
      @b.limit_n = 3
      @b.pruned_containers(items).should == items[0..2]
    end

    it "object_containers() should dispatch the correct method" do
      exp = {
        :discover_containers_via_manifest => true,
        :discover_items_via_crawl         => false,
      }
      exp.each do |meth, use_man|
        @b.object_discovery[:use_manifest] = use_man
        @b.stub(meth).and_return []
        @b.should_receive(meth).exactly(1).times
        @b.object_containers
      end
    end

    it "discover_containers_via_manifest() should return expected information" do
      col_name  = :col_foo
      vals      = %w(123.tif 456.tif 789.tif)
      exp       = vals.map { |v| "#{@b.bundle_dir}/#{v}" }
      fake_rows = vals.map { |v| double('row', col_name => v) }
      @b.manifest_cols[:object_container] = col_name
      @b.stub(:manifest_rows).and_return fake_rows
      @b.discover_containers_via_manifest.should == exp
    end

    it "discover_items_via_crawl() should return expected information" do
      items = [
        'abc.txt', 'def.txt', 'ghi.txt',
        '123.tif', '456.tif', '456.TIF',
      ]
      items = items.map { |i| "#{@b.bundle_dir}/#{i}" }
      @b.stub(:dir_glob).and_return items
      # No regex filtering.
      @b.object_discovery[:regex] = ''
      @b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery).should == items
      # Only tif files.
      @b.object_discovery[:regex] = '(?i)\.tif$'
      @b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery).should == items[3..-1]
    end

    it "dir_glob() should return expected information" do
      exp = [1,2,3].map { |n| "#{@b.bundle_dir}/image#{n}.tif" }
      @b.dir_glob("#{@b.bundle_dir}/*.tif").should == exp
    end

    it "stageable_items_for() should return [container] if use_container is true" do
      container = 'foo.tif'
      @b.stageable_discovery[:use_container] = true
      @b.stageable_items_for(container).should == [container] 
    end

    it "stageable_items_for() should return expected crawl results" do
      bundle_setup :yaml_rumsey
      container = "#{@b.bundle_dir}/cb837cp4412"
      exp = ['2874009.tif', 'descMetadata.xml'].map { |e| "#{container}/#{e}" }
      @b.stageable_items_for(container).should == exp
    end

  end

  
  describe "discover_all_files()" do

    before(:each) do
      bundle_setup :yaml_rumsey
      ds = %w(cb837cp4412 cm057cr1745 cp898cs9946)
      fs = %w(
        cb837cp4412/2874009.tif
        cb837cp4412/descMetadata.xml
        cm057cr1745/2874008.tif
        cm057cr1745/descMetadata.xml
        cp898cs9946/2874018.tif
        cp898cs9946/descMetadata.xml
      )
      @files = fs.map { |f| "#{@b.bundle_dir}/#{f}" }
      @dirs  = ds.map { |d| "#{@b.bundle_dir}/#{d}" }
    end

    it "should find files within directories" do
      @b.discover_all_files(@dirs).should == @files
    end

    it "should find files within directories, recursively" do
      @b.discover_all_files(@dirs).should == @files
    end

    it "should returns same arguments if given only files" do
      fs = @files[0..1]
      @b.discover_all_files(fs).should == fs
    end

  end


  describe "load_checksums()" do

    before(:each) do
      bundle_setup :yaml_revs
      # @b.discover_objects
    end

    it "zzzzz" do
      # @b.load_checksums
    end

  end


  describe "load_exp_checksums()" do

    before(:each) do
      bundle_setup :yaml_revs
    end

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
      bundle_setup :yaml_revs
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

    before(:each) do
      bundle_setup :yaml_revs
    end

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


  describe "file and directory utilities" do

    before(:each) do
      bundle_setup :yaml_revs
      @relative = 'abc/def.jpg'
      @full     = "#{@b.bundle_dir}/#{@relative}"
    end

    it "full_path_in_bundle_dir() should return expected value" do
      @b.full_path_in_bundle_dir(@relative).should == @full
    end

    it "relative_path() should return expected value" do
      @b.relative_path(@b.bundle_dir, @full).should == @relative
    end

    it "should be able to exercise file-dir existence methods" do
      @b.file_exists(@b.manifest).should == true
      @b.dir_exists(@b.bundle_dir).should == true
    end

    it "find_files_recursively() should return expected information" do
      exp = {
        :yaml_revs => [
          "checksums.txt", 
          "image1.tif", 
          "image2.tif", 
          "image3.tif", 
          "manifest.csv", 
          "mods_template.xml",
        ],
        :yaml_rumsey => [
          "cb837cp4412/2874009.tif",
          "cb837cp4412/descMetadata.xml",
          "cm057cr1745/2874008.tif",
          "cm057cr1745/descMetadata.xml",
          "cp898cs9946/2874018.tif",
          "cp898cs9946/descMetadata.xml",
        ],
      }
      exp.each do |project_style, files|
        bundle_setup project_style
        exp_files = files.map { |f| "#{@b.bundle_dir}/#{f}" }
        @b.find_files_recursively(@b.bundle_dir).sort.should == exp_files
      end
    end

  end


  describe "misc utilities" do

    before(:each) do
      bundle_setup :yaml_revs
    end

    it "source_id_suffix() should be empty if not making unique source IDs" do
      @b.uniqify_source_ids = false
      @b.source_id_suffix.should == ''
    end

    it "source_id_suffix() should look like an integer if making unique source IDs" do
      @b.uniqify_source_ids = true
      @b.source_id_suffix.should =~ /^_\d+$/
    end

    it "symbolize_keys() should handle various data structures correctly" do
      tests = [
        [ {}, {} ],
        [ [], [] ],
        [ [1,2], [1,2] ],
        [ 123, 123 ],
        [
          { :foo => 123, 'bar' => 456 },
          { :foo => 123, :bar  => 456 } 
        ],
        [
          { :foo => [1,2,3], 'bar' => { 'x' => 99, 'y' => { 'AA' => 22, 'BB' => 33 } } },
          { :foo => [1,2,3], :bar  => { :x  => 99, :y  => { :AA  => 22, :BB  => 33 } } },
        ],

      ]
      tests.each do |input, exp|
        PreAssembly::Bundle.symbolize_keys(input).should == exp
      end
    end
  end

end
