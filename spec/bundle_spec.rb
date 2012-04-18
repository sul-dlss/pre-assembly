describe PreAssembly::Bundle do

  before(:all) do
    @yaml = {
      :proj_revs   => File.read('config/projects/local_dev_revs.yaml'),
      :proj_rumsey => File.read('config/projects/local_dev_rumsey.yaml'),
    }
    @md5_regex = /^[0-9a-f]{32}$/
  end

  def bundle_setup(proj)
    @ps = YAML.load @yaml[proj]
    @b  = PreAssembly::Bundle.new @ps
  end

  ####################

  describe "initialize() and other setup" do

    before(:each) do
      bundle_setup :proj_revs
    end

    it "can initialize a Bundle" do
      @b.should be_kind_of PreAssembly::Bundle
    end

    it "load_desc_md_template() should return nil or String" do
      # Return nil if no template.
      @b.desc_md_template = nil
      @b.load_desc_md_template.should == nil
      # Otherwise, read the template and return its content.
      @b.desc_md_template = @b.path_in_bundle('mods_template.xml')
      template = @b.load_desc_md_template
      template.should be_kind_of String
      template.size.should > 0
    end

    it "setup_other() should prune @publish_attr" do
      # All keys are present.
      ks = @b.publish_attr.keys.map { |k| k.to_s }
      ks.sort.should == %w(preserve publish shelve)
      # Keys would nil values should be removed.
      @b.publish_attr[:preserve] = nil
      @b.publish_attr[:publish]  = nil
      @b.setup_other
      @b.publish_attr.keys.should == [:shelve]
    end

  end

  ####################

  describe "validate_usage()" do

    before(:each) do
      bundle_setup :proj_revs
      @b.user_params = Hash[ @b.required_user_params.map { |p| [p, ''] } ]
      @exp_err = PreAssembly::BundleUsageError
    end

    it "required_files() should return expected N of items" do
      @b.required_files.should have(3).items
      @b.manifest = nil
      @b.required_files.should have(2).items
      @b.checksums_file = nil
      @b.required_files.should have(1).items
      @b.desc_md_template = nil
      @b.required_files.should have(0).items
    end

    it "should do nothing if @validate_usage is false" do
      @b.validate_usage = false
      @b.should_not_receive(:required_user_params)
      @b.validate_usage
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

  ####################

  describe "main process" do

    before(:each) do
      bundle_setup :proj_revs
    end

    it "can exercise run_log_msg()" do
      @b.run_log_msg.should be_kind_of String
    end

    it "can exercise processed_pids()" do
      exp_pids = [11,22,33]
      @b.digital_objects = exp_pids.map { |p| double 'dobj', :pid => p }
      @b.processed_pids.should == exp_pids
    end



  end

  ####################

  describe "object discovery: discover_objects()" do

    it "discover_objects() should find the correct N objects, stageables, and files" do
      tests = [
        [ :proj_revs,   3, 1, 1 ],
        [ :proj_rumsey, 3, 2, 2 ],
      ]
      tests.each do |proj, n_dobj, n_stag, n_file|
        bundle_setup proj
        @b.discover_objects
        dobjs = @b.digital_objects
        dobjs.should have(n_dobj).items
        dobjs.each do |dobj|
          dobj.stageable_items.size.should == n_stag
          dobj.object_files.size.should == n_file
        end
      end
    end

    it "discover_objects() should handle containers correctly" do
      # A project that uses containers as stageables.
      # In this case, the bundle_dir serves as the container.
      bundle_setup :proj_revs
      @b.discover_objects
      @b.digital_objects[0].container.should == @b.bundle_dir
      # A project that does not.
      bundle_setup :proj_rumsey
      @b.discover_objects
      @b.digital_objects[0].container.size.should > @b.bundle_dir.size
    end

  end

  ####################

  describe "object discovery: containers" do

    before(:each) do
      bundle_setup :proj_revs
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

  end

  ####################

  describe "object discovery: discovery via manifest and crawl" do

    before(:each) do
      bundle_setup :proj_revs
    end

    it "discover_containers_via_manifest() should return expected information" do
      col_name  = :col_foo
      vals      = %w(123.tif 456.tif 789.tif)
      exp       = vals.map { |v| @b.path_in_bundle v }
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
      items = items.map { |i| @b.path_in_bundle i }
      @b.stub(:dir_glob).and_return items
      # No regex filtering.
      @b.object_discovery = { :regex => '', :glob => '' }
      @b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery).should == items
      # Only tif files.
      @b.object_discovery[:regex] = '(?i)\.tif$'
      @b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery).should == items[3..-1]
    end

  end

  ####################

  describe "object discovery: stageable_items_for" do

    before(:each) do
      bundle_setup :proj_revs
    end

    it "stageable_items_for() should return [container] if use_container is true" do
      container = 'foo.tif'
      @b.stageable_discovery[:use_container] = true
      @b.stageable_items_for(container).should == [container]
    end

    it "stageable_items_for() should return expected crawl results" do
      bundle_setup :proj_rumsey
      container = @b.path_in_bundle "cb837cp4412"
      exp = ['2874009.tif', 'descMetadata.xml'].map { |e| "#{container}/#{e}" }
      @b.stageable_items_for(container).should == exp
    end

  end

  ####################

  describe "object discovery: discover_all_files()" do

    before(:each) do
      bundle_setup :proj_rumsey
      ds = %w(cb837cp4412 cm057cr1745 cp898cs9946)
      fs = %w(
        cb837cp4412/2874009.tif
        cb837cp4412/descMetadata.xml
        cm057cr1745/2874008.tif
        cm057cr1745/descMetadata.xml
        cp898cs9946/2874018.tif
        cp898cs9946/descMetadata.xml
      )
      @files = fs.map { |f| @b.path_in_bundle f }
      @dirs  = ds.map { |d| @b.path_in_bundle d }
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

  ####################

  describe "object discovery: other" do

    before(:each) do
      bundle_setup :proj_revs
    end

    it "should be able to exercise all_object_files()" do
      bundle_setup :proj_revs
      fake_files = [[1,2], [3,4], [5,6]]
      fake_dobjs = fake_files.map { |fs| double('dobj', :object_files => fs) }
      @b.digital_objects = fake_dobjs
      @b.all_object_files.should == fake_files.flatten
    end

    it "new_object_file() should return an ObjectFile with expected path values" do
      bundle_setup :proj_revs
      rel_path = "image1.tif"
      path     = @b.path_in_bundle rel_path
      ofile    = @b.new_object_file @b.bundle_dir, path
      ofile.path.should          == path
      ofile.relative_path.should == rel_path
    end

    it "exclude_from_content() should behave correctly" do
      tests = {
        "image1.tif"       => false,
        "descMetadata.xml" => true,
      }
      bundle_setup :proj_rumsey
      tests.each do |f, exp|
        path = @b.path_in_bundle f
        @b.exclude_from_content(path).should == exp
      end
    end

  end

  ####################

  describe "checksums: load_checksums()" do

    it "should call load_provider_checksums() if the checksums file is present" do
      bundle_setup :proj_revs
      @b.should_receive(:all_object_files).and_return []
      @b.should_receive(:load_provider_checksums)
      @b.load_checksums
    end

    it "should call not call load_provider_checksums() when no checksums file is present" do
      bundle_setup :proj_rumsey
      @b.should_receive(:all_object_files).and_return []
      @b.should_not_receive(:load_provider_checksums)
      @b.load_checksums
    end

    it "should load checksums and attach them to the ObjectFiles" do
      bundle_setup :proj_rumsey
      @b.discover_objects
      @b.all_object_files.each { |f| f.checksum.should == nil }
      @b.load_checksums
      @b.all_object_files.each { |f| f.checksum.should =~ @md5_regex }
    end

  end

  ####################

  describe "checksums: load_provider_checksums()" do

    before(:each) do
      bundle_setup :proj_revs
    end

    it "empty string yields no checksums" do
      @b.stub(:read_exp_checksums).and_return('')
      @b.load_provider_checksums
      @b.provider_checksums.should == {}
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
      @b.load_provider_checksums
      @b.provider_checksums.should == checksum_data
    end

  end

  ####################

  describe "checksums: retrieving and computing" do

    before(:each) do
      bundle_setup :proj_revs
      @file_path = @b.path_in_bundle 'image1.tif'
      @checksum_type = :md5
    end

    it "retrieve_checksum() should return provider checksum when it is available" do
      fake_md5 = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
      @b.provider_checksums = { @file_path => fake_md5 }
      @b.should_not_receive :compute_checksum
      @b.retrieve_checksum(@file_path).should == fake_md5
    end

    it "retrieve_checksum() should compute checksum when checksum is not available" do
      @b.provider_checksums = {}
      @b.should_receive :compute_checksum
      @b.retrieve_checksum @file_path
    end

    it "compute_checksum() should return an md5 checksum" do
      c = @b.compute_checksum @file_path
      c.should be_kind_of String
      c.should =~ @md5_regex
    end

  end

  ####################

  describe "process_manifest()" do

    it "should do nothing for bundles that do not use a manifest" do
      bundle_setup :proj_rumsey
      @b.discover_objects
      @b.should_not_receive :manifest_rows
      @b.process_manifest
    end

    it "should augment the digital objects with additional information" do
      bundle_setup :proj_revs
      # Discover the objects: we should find some.
      @b.discover_objects
      @b.digital_objects.should have(3).items
      # Before processing manifest: various attributes should be nil.
      @b.digital_objects.each do |dobj|
        dobj.label.should        == nil
        dobj.source_id.should    == nil
        dobj.manifest_row.should == nil
      end
      # And now those attributes should have content.
      @b.process_manifest
      @b.digital_objects.each do |dobj|
        dobj.label.should be_kind_of        String
        dobj.source_id.should be_kind_of    String
        dobj.manifest_row.should be_kind_of Hash
      end
    end

  end

  ####################

  describe "manifest_rows()" do

    it "should load the manifest CSV only once" do
      bundle_setup :proj_revs
      # Stub out a method that reads the manifest CSV.
      fake_data = [0, 11, 222, 3333]
      meth_name = :load_manifest_rows_from_csv
      @b.stub(meth_name).and_return fake_data
      # Our stubbed method should be called only once, even though
      # we call manifest_rows() multiple times.
      @b.should_receive(meth_name).once
      3.times { @b.manifest_rows.should == fake_data }
    end

    it "should return empty array for bundles that do not use a manifest" do
      bundle_setup :proj_rumsey
      @b.manifest_rows.should == []
    end

  end

  ####################

  describe "validate_files()" do

    before(:each) do
      bundle_setup :proj_rumsey
    end

    it "should return expected tally if all images are valid" do
      @b.discover_objects
      @b.validate_files.should == { :valid => 3, :skipped => 3 }
    end

    it "should raise exception if one of the object files is an invalid image" do
      # Create a double that will simulate an invalid image.
      img_params = {:image? => true, :valid_image? => false, :path => 'bad/image.tif'}
      bad_image = double 'bad_image', img_params
      # Stub out all_object_files() to return that image.
      @b.stub(:all_object_files).and_return [ bad_image ]
      # Check for expected excption.
      exp_msg = /^File validation failed/
      lambda { @b.validate_files }.should raise_error(exp_msg)
    end

  end

  ####################

  describe "delete_digital_objects()" do

    before(:each) do
      bundle_setup :proj_revs
      @b.digital_objects = []
    end

    it "should do nothing if @cleanup == false" do
      @b.cleanup = false
      @b.digital_objects.should_not_receive :each
      @b.delete_digital_objects
    end

    it "should do something if @cleanup == true" do
      @b.cleanup = true
      @b.digital_objects.should_receive :each
      @b.delete_digital_objects
    end

  end

  ####################

  describe "file and directory utilities" do

    before(:each) do
      bundle_setup :proj_revs
      @relative = 'abc/def.jpg'
      @full     = @b.path_in_bundle @relative
    end

    it "path_in_bundle() should return expected value" do
      @b.path_in_bundle(@relative).should == @full
    end

    it "relative_path() should return expected value" do
      @b.relative_path(@b.bundle_dir, @full).should == @relative
    end

    it "relative_path() raise error if given bogus arguments" do
      f       = 'fubb.txt'
      base    = 'foo/bar'
      path    = "#{base}/#{f}"
      exp_err = ArgumentError
      exp_msg = /^Bad args to relative_path/
      lambda { @b.relative_path('',   path) }.should raise_error exp_err, exp_msg
      lambda { @b.relative_path(path, path) }.should raise_error exp_err, exp_msg
      lambda { @b.relative_path('xx', path) }.should raise_error exp_err, exp_msg
    end

    it "should be able to exercise file-dir existence methods" do
      @b.file_exists(@b.manifest).should == true
      @b.dir_exists(@b.bundle_dir).should == true
    end

    it "dir_glob() should return expected information" do
      exp = [1,2,3].map { |n| @b.path_in_bundle "image#{n}.tif" }
      @b.dir_glob(@b.path_in_bundle "*.tif").should == exp
    end

    it "find_files_recursively() should return expected information" do
      exp = {
        :proj_revs => [
          "checksums.txt",
          "image1.tif",
          "image2.tif",
          "image3.tif",
          "manifest.csv",
          "mods_template.xml",
        ],
        :proj_rumsey => [
          "cb837cp4412/2874009.tif",
          "cb837cp4412/descMetadata.xml",
          "cm057cr1745/2874008.tif",
          "cm057cr1745/descMetadata.xml",
          "cp898cs9946/2874018.tif",
          "cp898cs9946/descMetadata.xml",
        ],
      }
      exp.each do |proj, files|
        bundle_setup proj
        exp_files = files.map { |f| @b.path_in_bundle f }
        @b.find_files_recursively(@b.bundle_dir).sort.should == exp_files
      end
    end

  end

  ####################

  describe "misc utilities" do

    before(:each) do
      bundle_setup :proj_revs
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

    it "values_to_symbols!() should convert string values to symbols" do
      tests = [
        [ {}, {} ],
        [
          { :a => 123, :b => 'b', :c => 'ccc' },
          { :a => 123, :b => :b , :c => :ccc  },
        ],
      ]
      tests.each do |input, exp|
        PreAssembly::Bundle.values_to_symbols!(input).should == exp
      end
    end

  end

end
