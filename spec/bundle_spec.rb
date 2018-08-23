require 'spec_helper'

describe PreAssembly::Bundle do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }

  def bundle_setup(proj)
    filename = "spec/test_data/project_config_files/#{proj}.yaml"
    @ps = YAML.load(File.read(filename))
    @ps['config_filename'] = filename
    @ps['show_progress'] = false
    @b = PreAssembly::Bundle.new @ps
  end

  describe "initialize() and other setup" do
    before { bundle_setup :proj_revs }

    it "can initialize a Bundle" do
      expect(@b).to be_kind_of described_class
    end

    it "trims the trailing slash from the bundle directory" do
      expect(@b.bundle_dir).to eq('spec/test_data/bundle_input_a')
    end

    it "load_desc_md_template() should return nil or String" do
      # Return nil if no template.
      @b.desc_md_template = nil
      expect(@b.load_desc_md_template).to be_nil
      # Otherwise, read the template and return its content.
      @b.desc_md_template = @b.path_in_bundle('mods_template.xml')
      template = @b.load_desc_md_template
      expect(template).to be_kind_of String
      expect(template.size).to be > 0
    end

    it "setup_other() should prune @file_attr" do
      # All keys are present.
      expect(@b.file_attr.keys.map(&:to_s).sort).to eq(%w(preserve publish shelve))
      # Keys with nil values should be removed.
      @b.file_attr[:preserve] = nil
      @b.file_attr[:publish]  = nil
      @b.setup_other
      expect(@b.file_attr.keys).to eq([:shelve])
    end
  end

  describe '#apply_tag' do
    it "sets apply_tag to nil if not set in the yaml file" do
      expect(bundle_setup(:proj_revs).apply_tag).to be_nil
    end
    it "sets the apply_tag parameter if set" do
      expect(bundle_setup(:proj_revs_old_druid).apply_tag).to eq("revs:batch1")
    end
    it "sets the apply_tag to empty string or nil and be blank if set this way in config file" do
      expect(bundle_setup(:proj_revs_no_cm).apply_tag).to be_blank
      expect(bundle_setup(:proj_rumsey).apply_tag).to be_blank
    end
  end

  describe '#set_druid_id' do
    it "sets the set_druid_id to an array" do
      expect(bundle_setup(:proj_revs).set_druid_id).to eq(['druid:yt502zj0924', 'druid:nt028fd5773'])
    end
    it "sets the set_druid_id to nil" do
      expect(bundle_setup(:proj_rumsey).set_druid_id).to be_nil
    end
    it "sets the set_druid_id to a single value arrayed if one value is passed in a string" do
      expect(bundle_setup(:proj_revs_no_cm).set_druid_id).to eq(['druid:yt502zj0924'])
    end
  end

  describe '#load_skippables' do
    before { bundle_setup :proj_rumsey }

    it "does nothing if @resume is false" do
      @b.resume = false
      expect(@b).not_to receive(:read_progress_log)
      @b.load_skippables
    end

    it "returns expected hash of skippable items" do
      @b.resume = true
      @b.progress_log_file = 'spec/test_data/input/mock_progress_log.yaml'
      expect(@b.skippables).to eq({})
      @b.load_skippables
      expect(@b.skippables).to eq({ "aa" => true, "bb" => true })
    end
  end

  describe '#validate_usage with bad manifest' do
    it "raises an exception since the sourceID column is misspelled" do
      exp_msg = /Manifest does not have a column called 'sourceid'/
      expect { bundle_setup(:proj_revs_bad_manifest) }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end
  end

  describe '#import_csv' do
    let(:manifest) do
      described_class.import_csv("#{PRE_ASSEMBLY_ROOT}/spec/test_data/bundle_input_a/manifest.csv")
    end

    it "loads a CSV as a hash with indifferent access" do
      expect(manifest).to be_an(Array)
      expect(manifest.size).to eq(3)
      headers = %w{format sourceid filename label year inst_notes prod_notes has_more_metadata description}
      # rows should be accessible as keys by header, both as string and symbols
      expect(manifest).to all(include(*headers))
      expect(manifest).to all(include(*headers.map(&:to_sym)))
      # test some specific values by key and string -- if the column is totally missing at the end, it might have a value of nil (like in the first row, missing the description column)
      expect(manifest[0][:description]).to be_nil
      expect(manifest[0]['description']).to be_nil
      expect(manifest[1][:description]).to eq('')
      expect(manifest[1]['description']).not_to be_nil
      expect(manifest[2][:description]).to eq('yo, this is a description')
      expect(manifest[2]['description']).to eq('yo, this is a description')
      expect(manifest[2]['Description']).to be_nil # AKA Hashes, how do they work?
    end
  end

  describe '#validate_usage' do
    before do
      bundle_setup(:proj_revs).user_params = Hash[@b.required_user_params.map { |p| [p, ''] }]
    end

    it "required_files() should return expected N of items" do
      expect(@b.required_files.size).to eq(3)
      @b.manifest = nil
      expect(@b.required_files.size).to eq(2)
      @b.checksums_file = nil
      expect(@b.required_files.size).to eq(1)
      @b.desc_md_template = nil
      expect(@b.required_files.size).to eq(0)
    end

    it "does nothing if @validate_usage is false" do
      @b.validate_usage = false
      expect(@b).not_to receive(:required_user_params)
      @b.validate_usage
    end

    it "does not raise an exception if requirements are satisfied" do
      expect { @b.validate_usage }.not_to raise_error
    end

    it "raises exception if a user parameter is missing" do
      @b.user_params.delete :bundle_dir
      exp_msg = /^Configuration errors found:  Missing parameter: /
      expect { @b.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if required directory not found" do
      @b.bundle_dir = '__foo_bundle_dir###'
      exp_msg = /^Configuration errors found:  Required directory not found/
      expect { @b.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if required file not found" do
      @b.manifest = '__foo_manifest###'
      exp_msg = /^Configuration errors found:  Required file not found/
      expect { @b.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if use_container and get_druid_from are incompatible" do
      @b.stageable_discovery[:use_container] = true
      exp_msg = /^Configuration errors found:  If stageable_discovery:use_container=true, you cannot use get_druid_from='container'/
      [:container, :container_barcode].each do |gdf|
        @b.project_style[:get_druid_from] = gdf
        expect { @b.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
      end
    end
  end

  describe "main process" do
    before { bundle_setup :proj_revs }

    it "can exercise run_log_msg()" do
      expect(@b.run_log_msg).to be_kind_of String
    end

    it "can exercise processed_pids()" do
      exp_pids = [11, 22, 33]
      @b.digital_objects = exp_pids.map { |p| double('dobj', :pid => p) }
      expect(@b.processed_pids).to eq(exp_pids)
    end
  end

  describe "bundle directory validation using DirValidator" do
    before { bundle_setup :proj_rumsey }

    it "run_pre_assembly() should short-circuit if the bundle directory is invalid" do
      allow(@b).to receive('bundle_directory_is_valid?').and_return(false)
      methods = [
        :discover_objects,
        :load_provider_checksums,
        :process_manifest,
        :process_digital_objects,
        :delete_digital_objects,
      ]
      methods.each { |m| expect(@b).not_to receive(m) }
      @b.run_pre_assembly
    end

    describe '#bundle_directory_is_valid?' do
      it "returns true when no validation is requested by client" do
        @b.validate_bundle_dir = {}
        expect(@b.bundle_directory_is_valid?).to eq(true)
      end

      it "returns true if there are no validation errors, otherwise false" do
        @b.validate_bundle_dir = { :code => 'some_validation_code.rb' }
        allow(@b).to receive(:write_validation_warnings)
        tests = {
          [] => true,
          [1, 2] => false,
        }
        tests.each do |ws, exp|
          v = double('mock_validator', :validate => nil, :warnings => ws)
          allow(@b).to receive(:run_dir_validation_code).and_return(v)
          expect(@b.bundle_directory_is_valid?).to eq(exp)
        end
      end
    end
  end

  describe 'object discovery: #discover_objects' do
    it "finds the correct N objects, stageables, and files" do
      tests = [
        [:proj_revs,   3, 1, 1],
        [:proj_rumsey, 3, 2, 2],
        [:folder_manifest, 3, 2, 2],
        [:sohp_files_only, 2, 9, 9],
        [:sohp_files_and_folders, 2, 25, 40]
      ]
      tests.each do |proj, n_dobj, n_stag, n_file|
        b = bundle_setup(proj)
        b.discover_objects
        dobjs = b.digital_objects
        expect(dobjs.size).to eq(n_dobj)
        dobjs.each do |dobj|
          expect(dobj.stageable_items.size).to eq(n_stag)
          expect(dobj.object_files.size).to eq(n_file)
        end
      end
    end

    it "handles containers correctly" do
      # A project that uses containers as stageables.
      # In this case, the bundle_dir serves as the container.
      b = bundle_setup(:proj_revs)
      b.discover_objects
      expect(b.digital_objects[0].container).to eq(b.bundle_dir)
      # A project that does not.
      b = bundle_setup(:proj_rumsey)
      b.discover_objects
      expect(b.digital_objects[0].container.size).to be > b.bundle_dir.size
    end
  end

  describe "object discovery: containers" do
    before { bundle_setup :proj_revs }

    it "@pruned_containers should limit N of discovered objects if @limit_n is defined" do
      items = [0, 11, 22, 33, 44, 55, 66, 77]
      @b.limit_n = nil
      expect(@b.pruned_containers(items)).to eq(items)
      @b.limit_n = 3
      expect(@b.pruned_containers(items)).to eq(items[0..2])
    end

    it "object_containers() should dispatch the correct method" do
      exp = {
        :discover_containers_via_manifest => true,
        :discover_items_via_crawl         => false,
      }
      exp.each do |meth, use_man|
        @b.object_discovery[:use_manifest] = use_man
        allow(@b).to receive(meth).and_return []
        expect(@b).to receive(meth).once
        @b.object_containers
      end
    end
  end

  describe "object discovery: discovery via manifest and crawl" do
    before { bundle_setup :proj_revs }

    it "discover_containers_via_manifest() should return expected information" do
      vals = %w(123.tif 456.tif 789.tif)
      @b.manifest_cols[:object_container] = :col_foo
      allow(@b).to receive(:manifest_rows).and_return(vals.map { |v| { :col_foo => v } })
      expect(@b.discover_containers_via_manifest).to eq(vals.map { |v| @b.path_in_bundle v })
    end

    it "discover_items_via_crawl() should return expected information" do
      items = [
        'abc.txt', 'def.txt', 'ghi.txt',
        '123.tif', '456.tif', '456.TIF',
      ]
      items = items.map { |i| @b.path_in_bundle i }
      allow(@b).to receive(:dir_glob).and_return(items)
      # No regex filtering.
      @b.object_discovery = { :regex => '', :glob => '' }
      expect(@b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery)).to eq(items.sort)
      # No regex filtering: using nil as regex.
      @b.object_discovery = { :regex => nil, :glob => '' }
      expect(@b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery)).to eq(items.sort)
      # Only tif files.
      @b.object_discovery[:regex] = '(?i)\.tif$'
      expect(@b.discover_items_via_crawl(@b.bundle_dir, @b.object_discovery)).to eq(items[3..-1].sort)
    end
  end

  describe "object discovery: stageable_items_for" do
    before { bundle_setup :proj_revs }

    it "stageable_items_for() should return [container] if use_container is true" do
      @b.stageable_discovery[:use_container] = true
      expect(@b.stageable_items_for('foo.tif')).to eq(['foo.tif'])
    end

    it "stageable_items_for() should return expected crawl results" do
      b = bundle_setup(:proj_rumsey)
      container = b.path_in_bundle "cb837cp4412"
      exp = ['2874009.tif', 'descMetadata.xml'].map { |e| "#{container}/#{e}" }
      expect(b.stageable_items_for(container)).to eq(exp)
    end
  end

  describe "object discovery: discover_object_files()" do
    let(:fs) do
      %w(
        cb837cp4412/2874009.tif
        cb837cp4412/descMetadata.xml
        cm057cr1745/2874008.tif
        cm057cr1745/descMetadata.xml
        cp898cs9946/2874018.tif
        cp898cs9946/descMetadata.xml
      )
    end
    let(:files) { fs.map { |f| @b.path_in_bundle f } }
    let(:dirs) { %w(cb837cp4412 cm057cr1745 cp898cs9946).map { |d| @b.path_in_bundle d } }

    before { bundle_setup :proj_rumsey }

    it "finds expected files with correct relative paths" do
      tests = [
        # Stageables.    Expected relative paths.                 Type of item as stageables.
        [files,         fs.map { |f| File.basename f }], # Files.
        [dirs,          fs], # Directories.
        [@b.bundle_dir, fs.map { |f| File.join(File.basename(@b.bundle_dir), f) }], # Even higher directory.
      ]
      tests.each do |stageables, exp_relative_paths|
        # Full paths of object files should never change, but the relative paths varies, depending on the stageables.
        ofiles = @b.discover_object_files(stageables)
        expect(ofiles.map(&:path)).to eq(files)
        expect(ofiles.map(&:relative_path)).to eq(exp_relative_paths)
      end
    end
  end

  describe "object discovery: other" do
    before { bundle_setup :proj_revs }

    it "actual_container() should behave as expected" do
      path = "foo/bar/x.tif"
      # Return the container unmodified.
      @b.stageable_discovery[:use_container] = false
      expect(@b.actual_container(path)).to eq(path)
      # Adjust the container value.
      @b.stageable_discovery[:use_container] = true
      expect(@b.actual_container(path)).to eq('foo/bar')
    end

    it "is able to exercise all_object_files()" do
      fake_files = [[1, 2], [3, 4], [5, 6]]
      fake_dobjs = fake_files.map { |fs| double('dobj', :object_files => fs) }
      @b.digital_objects = fake_dobjs
      expect(@b.all_object_files).to eq(fake_files.flatten)
    end

    it "new_object_file() should return an ObjectFile with expected path values" do
      allow(@b).to receive(:exclude_from_path).and_return(false)
      tests = [
        # Stageable is a file:
        # - immediately in bundle dir.
        { :stageable    => 'BUNDLE/x.tif',
          :file_path    => 'BUNDLE/x.tif',
          :exp_rel_path => 'x.tif' },
        # - within subdir of bundle dir.
        { :stageable    => 'BUNDLE/a/b/x.tif',
          :file_path    => 'BUNDLE/a/b/x.tif',
          :exp_rel_path => 'x.tif' },
        # Stageable is a directory:
        # - immediately in bundle dir
        { :stageable    => 'BUNDLE/a',
          :file_path    => 'BUNDLE/a/x.tif',
          :exp_rel_path => 'a/x.tif' },
        # - immediately in bundle dir, with file deeper
        { :stageable    => 'BUNDLE/a',
          :file_path    => 'BUNDLE/a/b/x.tif',
          :exp_rel_path => 'a/b/x.tif' },
        # - within a subdir of bundle dir
        { :stageable    => 'BUNDLE/a/b',
          :file_path    => 'BUNDLE/a/b/x.tif',
          :exp_rel_path => 'b/x.tif' },
        # - within a subdir of bundle dir, with file deeper
        { :stageable    => 'BUNDLE/a/b',
          :file_path    => 'BUNDLE/a/b/c/d/x.tif',
          :exp_rel_path => 'b/c/d/x.tif' },
      ]
      tests.each do |t|
        ofile = @b.new_object_file t[:stageable], t[:file_path]
        expect(ofile).to be_kind_of PreAssembly::ObjectFile
        expect(ofile.path).to          eq(t[:file_path])
        expect(ofile.relative_path).to eq(t[:exp_rel_path])
      end
    end

    it "exclude_from_content() should behave correctly" do
      b = bundle_setup(:proj_rumsey)
      expect(b.exclude_from_content(b.path_in_bundle('image1.tif'))).to be_falsey
      expect(b.exclude_from_content(b.path_in_bundle('descMetadata.xml'))).to be_truthy
    end
  end

  describe "checksums: load_checksums()" do
    it "loads checksums and attach them to the ObjectFiles" do
      b = bundle_setup(:proj_rumsey)
      b.discover_objects
      b.all_object_files.each { |f|    expect(f.checksum).to be_nil }
      b.digital_objects.each  { |dobj| b.load_checksums(dobj) }
      b.all_object_files.each { |f|    expect(f.checksum).to match(md5_regex) }
    end
  end

  describe "checksums: load_provider_checksums()" do
    before { bundle_setup :proj_revs }

    it "does nothing when no checksums file is present" do
      b = bundle_setup(:proj_rumsey)
      expect(b).not_to receive(:read_exp_checksums)
      b.load_provider_checksums
    end

    it "empty string yields no checksums" do
      allow(@b).to receive(:read_exp_checksums).and_return('')
      @b.load_provider_checksums
      expect(@b.provider_checksums).to eq({})
    end

    it "checksums are parsed correctly" do
      checksum_data = {
        'foo1.tif' => '4e3cd24dd79f3ec91622d9f8e5ab5afa',
        'foo2.tif' => '7e40beb08d646044529b9138a5f1c796',
        'foo3.tif' => 'e5263af3ebb27d4ab44f70317cb249c1',
        'foo4.tif' => '15263af3ebb27d4ab44f74316cb249a4',
      }
      checksum_string = checksum_data.map { |f, c| "MD5 (#{f}) = #{c}\n" }.join ''
      allow(@b).to receive(:read_exp_checksums).and_return(checksum_string)
      @b.load_provider_checksums
      expect(@b.provider_checksums).to eq(checksum_data)
    end
  end

  describe "checksums: retrieving and computing" do
    let(:file_path) { @b.path_in_bundle 'image1.tif' }
    let(:file) { Assembly::ObjectFile.new(file_path) }

    before { bundle_setup :proj_revs }

    it "retrieve_checksum() should return provider checksum when it is available" do
      fake_md5 = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
      @b.provider_checksums = { file_path => fake_md5 }
      expect(@b).not_to receive(:compute_checksum)
      expect(@b.retrieve_checksum(file)).to eq(fake_md5)
    end

    it "retrieve_checksum() should compute checksum when checksum is not available" do
      @b.provider_checksums = {}
      expect(@b).to receive(:compute_checksum)
      @b.retrieve_checksum(file)
    end

    it "compute_checksum() should return nil if @compute_checksum is false" do
      @b.compute_checksum = false
      expect(@b.compute_checksum(file)).to be_nil
    end

    it "compute_checksum() should return an md5 checksum" do
      expect(@b.compute_checksum(file)).to be_a(String).and match(md5_regex)
    end
  end

  describe '#process_manifest' do
    it "does nothing for bundles that do not use a manifest" do
      b = bundle_setup(:proj_rumsey)
      b.discover_objects
      expect(b).not_to receive :manifest_rows
      b.process_manifest
    end

    it "augments the digital objects with additional information" do
      b = bundle_setup(:proj_revs)
      # Discover the objects: we should find some.
      b.discover_objects
      expect(b.digital_objects.size).to eq(3)
      # Before processing manifest: various attributes should be nil or default value.
      b.digital_objects.each do |dobj|
        expect(dobj.label).to        eq(Dor::Config.dor.default_label)
        expect(dobj.source_id).to    be_nil
        expect(dobj.manifest_row).to be_nil
      end
      # And now those attributes should have content.
      b.process_manifest
      b.digital_objects.each do |dobj|
        expect(dobj.label).to be_kind_of String
        expect(dobj.label).not_to eq(Dor::Config.dor.default_label)
        expect(dobj.source_id).to be_kind_of    String
        expect(dobj.manifest_row).to be_kind_of Hash
      end
    end
  end

  describe '#manifest_rows' do
    it "loads the manifest CSV only once, during the validation phase, and return all three rows even if you access the manifest multiple times" do
      b = bundle_setup(:proj_revs)
      expect(b).not_to receive(:load_manifest_rows_from_csv)
      3.times { b.manifest_rows.size == 3 }
    end

    it "returns empty array for bundles that do not use a manifest" do
      expect(bundle_setup(:proj_rumsey).manifest_rows).to eq([])
    end
  end

  describe '#validate_files' do
    before { bundle_setup(:proj_rumsey).discover_objects }

    it "returns expected tally if all images are valid" do
      skip "validate_files has depedencies on exiftool, making it sometimes incorrectly fail...it basically exercises methods already adequately tested in the assembly-objectfile gem"
      @b.digital_objects.each do |dobj|
        expect(@b.validate_files(dobj)).to eq({ :valid => 1, :skipped => 1 })
      end
    end

    it "raises exception if one of the object files is an invalid image" do
      # Create a double that will simulate an invalid image.
      img_params = { :image? => true, :valid_image? => false, :path => 'bad/image.tif' }
      bad_image  = double 'bad_image', img_params
      # Check for exceptions.
      exp_msg    = /^File validation failed/
      @b.digital_objects.each do |dobj|
        dobj.object_files = [bad_image]
        expect { @b.validate_files(dobj) }.to raise_error(exp_msg)
      end
    end
  end

  describe '#objects_to_process' do
    it "has the correct list of objects to re-accession if specified with only option" do
      b = bundle_setup(:proj_sohp3)
      b.discover_objects
      expect(b.digital_objects.size).to eq(2)
      o2p = b.objects_to_process
      expect(o2p.size).to eq(1)
    end

    it "has the correct list of objects to accession if specified with except option" do
      b = bundle_setup(:proj_sohp4)
      b.discover_objects
      expect(b.digital_objects.size).to eq(2)
      o2p = b.objects_to_process
      expect(o2p.size).to eq(0)
    end

    it "returns all objects if there are no skippables" do
      b = bundle_setup(:proj_revs)
      b.discover_objects
      b.skippables = {}
      expect(b.objects_to_process).to eq(b.digital_objects)
    end

    it "returns a filtered list of digital objects" do
      b = bundle_setup(:proj_revs)
      b.discover_objects
      b.skippables = {}
      b.skippables[b.digital_objects[-1].unadjusted_container] = true
      o2p = b.objects_to_process
      expect(o2p.size).to eq(b.digital_objects.size - 1)
      expect(o2p).to eq(b.digital_objects[0..-2])
    end
  end

  describe "setup_paths and defaults" do
    it "sets the staging_dir to the value specified in YAML" do
      b = bundle_setup(:proj_revs)
      b.setup_paths
      expect(b.staging_dir).to eq('tmp')
    end

    it "sets the progress log file to match the input yaml file if no progress log is specified in YAML" do
      b = bundle_setup(:proj_sohp3)
      b.setup_paths
      expect(b.progress_log_file).to eq('spec/test_data/project_config_files/proj_sohp3_progress.yaml')
    end

    it "sets the content_tag_override to the default value when not specified" do
      b = bundle_setup(:proj_revs)
      expect(@ps['project_style'][:content_tag_override]).to be_nil
      expect(b.project_style[:content_tag_override]).to be_falsey
    end

    it "sets the staging_dir to the default value if not specified in the YAML" do
      default_staging_directory = Assembly::ASSEMBLY_WORKSPACE
      if File.exist?(default_staging_directory) && File.directory?(default_staging_directory)
        b = bundle_setup(:proj_sohp2)
        b.setup_paths
        expect(b.staging_dir).to eq(default_staging_directory)
      else
        expect { bundle_setup :proj_sohp2 }.to raise_error PreAssembly::BundleUsageError
      end
    end
  end

  describe "#log_progress_info" do
    it "returns expected info about a digital object" do
      b = bundle_setup(:proj_revs)
      b.discover_objects
      dobj = b.digital_objects[0]
      exp = {
        :unadjusted_container => dobj.unadjusted_container,
        :pid                  => dobj.pid,
        :pre_assem_finished   => dobj.pre_assem_finished,
        :timestamp            => Time.now.strftime('%Y-%m-%d %H:%I:%S')
      }
      expect(b.log_progress_info(dobj)).to eq(exp)
    end
  end

  describe "#delete_digital_objects" do
    before { bundle_setup(:proj_revs).digital_objects = [] }

    it "does nothing if @cleanup == false" do
      @b.cleanup = false
      expect(@b.digital_objects).not_to receive :each
      @b.delete_digital_objects
    end

    it "does something if @cleanup == true" do
      @b.cleanup = true
      expect(@b.digital_objects).to receive :each
      @b.delete_digital_objects
    end
  end

  describe "file and directory utilities" do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { @b.path_in_bundle(relative) }

    before { bundle_setup :proj_revs }

    it "#path_in_bundle returns expected value" do
      expect(@b.path_in_bundle(relative)).to eq('spec/test_data/bundle_input_a/abc/def.jpg')
    end

    it "#relative_path returns expected value" do
      expect(@b.relative_path(@b.bundle_dir, full)).to eq(relative)
    end

    it "#relative_path raises error if given bogus arguments" do
      path = "foo/bar/fubb.txt"
      exp_msg = /^Bad args to relative_path/
      expect { @b.relative_path('',   path) }.to raise_error(ArgumentError, exp_msg)
      expect { @b.relative_path(path, path) }.to raise_error(ArgumentError, exp_msg)
      expect { @b.relative_path('xx', path) }.to raise_error(ArgumentError, exp_msg)
    end

    it "#get_base_dir returns expected value" do
      expect(@b.get_base_dir('foo/bar/fubb.txt')).to eq('foo/bar')
    end

    it "#get_base_dir raises error if given bogus arguments" do
      exp_msg  = /^Bad arg to get_base_dir/
      bad_args = ['foo.txt', '', 'x\y\foo.txt']
      bad_args.each do |arg|
        expect { @b.get_base_dir(arg) }.to raise_error(ArgumentError, exp_msg)
      end
    end

    it "#dir_glob returns expected information" do
      exp = [1, 2, 3].map { |n| @b.path_in_bundle "image#{n}.tif" }
      expect(@b.dir_glob(@b.path_in_bundle "*.tif")).to eq(exp)
    end

    it "#find_files_recursively returns expected information" do
      exp = {
        :proj_revs => [
          "checksums.txt",
          "image1.tif",
          "image2.tif",
          "image3.tif",
          "manifest.csv",
          "manifest_badsourceid_column.csv",
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
        b = bundle_setup(proj)
        exp_files = files.map { |f| b.path_in_bundle f }
        expect(b.find_files_recursively(b.bundle_dir).sort).to eq(exp_files)
      end
    end
  end

  describe "misc utilities" do
    before { bundle_setup :proj_revs }

    it '#source_id_suffix is empty if not making unique source IDs' do
      @b.uniqify_source_ids = false
      expect(@b.source_id_suffix).to eq('')
    end

    it '#source_id_suffix looks like an integer if making unique source IDs' do
      @b.uniqify_source_ids = true
      expect(@b.source_id_suffix).to match(/^_\d+$/)
    end

    it '#symbolize_keys handles various data structures correctly' do
      tests = [
        [{}, {}],
        [[], []],
        [[1, 2], [1, 2]],
        [123, 123],
        [
          { :foo => 123, 'bar' => 456 },
          { :foo => 123, :bar  => 456 }
        ],
        [
          { :foo => [1, 2, 3], 'bar' => { 'x' => 99, 'y' => { 'AA' => 22, 'BB' => 33 } } },
          { :foo => [1, 2, 3], :bar  => { :x  => 99, :y  => { :AA  => 22, :BB  => 33 } } },
        ],

      ]
      tests.each do |input, exp|
        expect(Assembly::Utils.symbolize_keys(input)).to eq(exp)
      end
    end

    it '#values_to_symbols! should convert string values to symbols' do
      tests = [
        [{}, {}],
        [
          { :a => 123, :b => 'b', :c => 'ccc' },
          { :a => 123, :b => :b, :c => :ccc },
        ],
      ]
      tests.each do |input, exp|
        expect(Assembly::Utils.values_to_symbols!(input)).to eq(exp)
      end
    end
  end
end
