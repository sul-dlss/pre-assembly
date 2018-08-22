require 'spec_helper'

describe PreAssembly::Bundle do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }
  let(:revs)   { bundle_setup(:proj_revs) }
  let(:rumsey) { bundle_setup(:proj_rumsey) }

  def bundle_setup(proj)
    filename = "spec/test_data/project_config_files/#{proj}.yaml"
    @ps = YAML.load(File.read(filename))
    @ps['config_filename'] = filename
    @ps['show_progress'] = false
    PreAssembly::Bundle.new(@ps)
  end

  describe "initialize() and other setup" do
    it "trims the trailing slash from the bundle directory" do
      expect(revs.bundle_dir).to eq('spec/test_data/bundle_input_a')
    end

    it '#load_desc_md_template should return nil or String' do
      # Return nil if no template.
      revs.desc_md_template = nil
      expect(revs.load_desc_md_template).to be_nil
      # Otherwise, read the template and return its content.
      revs.desc_md_template = revs.path_in_bundle('mods_template.xml')
      template = revs.load_desc_md_template
      expect(template).to be_a(String)
      expect(template.size).to be > 0
    end

    it '#setup_other should prune @file_attr' do
      # All keys are present.
      expect(revs.file_attr.keys.map(&:to_s).sort).to eq(%w(preserve publish shelve))
      # Keys with nil values should be removed.
      revs.file_attr[:preserve] = nil
      revs.file_attr[:publish]  = nil
      revs.setup_other
      expect(revs.file_attr.keys).to eq([:shelve])
    end
  end

  describe '#apply_tag' do
    it "sets apply_tag to nil if not set in the yaml file" do
      expect(revs.apply_tag).to be_nil
    end
    it "sets the apply_tag parameter if set" do
      expect(bundle_setup(:proj_revs_old_druid).apply_tag).to eq("revs:batch1")
    end
    it "sets the apply_tag to empty string or nil and be blank if set this way in config file" do
      expect(bundle_setup(:proj_revs_no_cm).apply_tag).to be_blank
      expect(rumsey.apply_tag).to be_blank
    end
  end

  describe '#set_druid_id' do
    it "sets the set_druid_id to an array" do
      expect(revs.set_druid_id).to eq(['druid:yt502zj0924', 'druid:nt028fd5773'])
    end
    it "sets the set_druid_id to nil" do
      expect(rumsey.set_druid_id).to be_nil
    end
    it "sets the set_druid_id to a single value arrayed if one value is passed in a string" do
      expect(bundle_setup(:proj_revs_no_cm).set_druid_id).to eq(['druid:yt502zj0924'])
    end
  end

  describe '#load_skippables' do
    it "does nothing if @resume is false" do
      rumsey.resume = false
      expect(rumsey).not_to receive(:read_progress_log)
      rumsey.load_skippables
    end

    it "returns expected hash of skippable items" do
      rumsey.resume = true
      rumsey.progress_log_file = 'spec/test_data/input/mock_progress_log.yaml'
      expect(rumsey.skippables).to eq({})
      rumsey.load_skippables
      expect(rumsey.skippables).to eq({ "aa" => true, "bb" => true })
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
    before { revs.user_params = Hash[revs.required_user_params.map { |p| [p, ''] }] }

    it '#required_files should return expected N of items' do
      expect(revs.required_files.size).to eq(3)
      revs.manifest = nil
      expect(revs.required_files.size).to eq(2)
      revs.checksums_file = nil
      expect(revs.required_files.size).to eq(1)
      revs.desc_md_template = nil
      expect(revs.required_files.size).to eq(0)
    end

    it "does nothing if @validate_usage is false" do
      revs.validate_usage = false
      expect(revs).not_to receive(:required_user_params)
      revs.validate_usage
    end

    it "does not raise an exception if requirements are satisfied" do
      expect { revs.validate_usage }.not_to raise_error
    end

    it "raises exception if a user parameter is missing" do
      revs.user_params.delete :bundle_dir
      exp_msg = /^Configuration errors found:  Missing parameter: /
      expect { revs.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if required directory not found" do
      revs.bundle_dir = '__foo_bundle_dir###'
      exp_msg = /^Configuration errors found:  Required directory not found/
      expect { revs.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if required file not found" do
      revs.manifest = '__foo_manifest###'
      exp_msg = /^Configuration errors found:  Required file not found/
      expect { revs.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if use_container and get_druid_from are incompatible" do
      revs.stageable_discovery[:use_container] = true
      exp_msg = /^Configuration errors found:  If stageable_discovery:use_container=true, you cannot use get_druid_from='container'/
      [:container, :container_barcode].each do |gdf|
        revs.project_style[:get_druid_from] = gdf
        expect { revs.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
      end
    end
  end

  describe '#run_log_msg' do
    it '#returns a string' do
      expect(revs.run_log_msg).to be_a(String)
    end
  end

  describe '#processed_pids' do
    it 'pulls pids from digital_objects' do
      exp_pids = [11, 22, 33]
      revs.digital_objects = exp_pids.map { |p| double('dobj', :pid => p) }
      expect(revs.processed_pids).to eq(exp_pids)
    end
  end

  describe "bundle directory validation using DirValidator" do
    it '#run_pre_assembly short-circuit if the bundle directory is invalid' do
      allow(rumsey).to receive('bundle_directory_is_valid?').and_return(false)
      methods = [
        :discover_objects,
        :load_provider_checksums,
        :process_manifest,
        :process_digital_objects,
        :delete_digital_objects,
      ]
      methods.each { |m| expect(rumsey).not_to receive(m) }
      rumsey.run_pre_assembly
    end

    describe '#bundle_directory_is_valid?' do
      it "returns true when no validation is requested by client" do
        rumsey.validate_bundle_dir = {}
        expect(rumsey.bundle_directory_is_valid?).to eq(true)
      end

      it "returns true if there are no validation errors, otherwise false" do
        rumsey.validate_bundle_dir = { :code => 'some_validation_code.rb' }
        allow(rumsey).to receive(:write_validation_warnings)
        tests = {
          [] => true,
          [1, 2] => false,
        }
        tests.each do |ws, exp|
          v = double('mock_validator', :validate => nil, :warnings => ws)
          allow(rumsey).to receive(:run_dir_validation_code).and_return(v)
          expect(rumsey.bundle_directory_is_valid?).to eq(exp)
        end
      end
    end
  end

  describe 'object discovery: #discover_objects' do
    let(:tests) do
      [
        [:proj_revs,   3, 1, 1],
        [:proj_rumsey, 3, 2, 2],
        [:folder_manifest, 3, 2, 2],
        [:sohp_files_only, 2, 9, 9],
        [:sohp_files_and_folders, 2, 25, 40]
      ]
    end

    it "finds the correct N objects, stageables, and files" do
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
      revs.discover_objects
      expect(revs.digital_objects[0].container).to eq(revs.bundle_dir)
      # A project that does not.
      rumsey.discover_objects
      expect(rumsey.digital_objects[0].container.size).to be > rumsey.bundle_dir.size
    end
  end

  describe "object discovery: containers" do
    it "@pruned_containers should limit N of discovered objects if @limit_n is defined" do
      items = [0, 11, 22, 33, 44, 55, 66, 77]
      revs.limit_n = nil
      expect(revs.pruned_containers(items)).to eq(items)
      revs.limit_n = 3
      expect(revs.pruned_containers(items)).to eq(items[0..2])
    end

    it "object_containers() should dispatch the correct method" do
      exp = {
        :discover_containers_via_manifest => true,
        :discover_items_via_crawl         => false,
      }
      exp.each do |meth, use_man|
        revs.object_discovery[:use_manifest] = use_man
        allow(revs).to receive(meth).and_return []
        expect(revs).to receive(meth).once
        revs.object_containers
      end
    end
  end

  describe "object discovery: discovery via manifest and crawl" do
    it "discover_containers_via_manifest() should return expected information" do
      vals = %w(123.tif 456.tif 789.tif)
      revs.manifest_cols[:object_container] = :col_foo
      allow(revs).to receive(:manifest_rows).and_return(vals.map { |v| { :col_foo => v } })
      expect(revs.discover_containers_via_manifest).to eq(vals.map { |v| revs.path_in_bundle v })
    end

    it "discover_items_via_crawl() should return expected information" do
      items = [
        'abc.txt', 'def.txt', 'ghi.txt',
        '123.tif', '456.tif', '456.TIF',
      ]
      items = items.map { |i| revs.path_in_bundle i }
      allow(revs).to receive(:dir_glob).and_return(items)
      # No regex filtering.
      revs.object_discovery = { :regex => '', :glob => '' }
      expect(revs.discover_items_via_crawl(revs.bundle_dir, revs.object_discovery)).to eq(items.sort)
      # No regex filtering: using nil as regex.
      revs.object_discovery = { :regex => nil, :glob => '' }
      expect(revs.discover_items_via_crawl(revs.bundle_dir, revs.object_discovery)).to eq(items.sort)
      # Only tif files.
      revs.object_discovery[:regex] = '(?i)\.tif$'
      expect(revs.discover_items_via_crawl(revs.bundle_dir, revs.object_discovery)).to eq(items[3..-1].sort)
    end
  end

  describe 'object discovery: #stageable_items_for' do
    it 'returns [container] if use_container is true' do
      revs.stageable_discovery[:use_container] = true
      expect(revs.stageable_items_for('foo.tif')).to eq(['foo.tif'])
    end

    it 'returns expected crawl results' do
      container = rumsey.path_in_bundle('cb837cp4412')
      exp = ['2874009.tif', 'descMetadata.xml'].map { |e| "#{container}/#{e}" }
      expect(rumsey.stageable_items_for(container)).to eq(exp)
    end
  end

  describe 'object discovery: #discover_object_files' do
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
    let(:files) { fs.map { |f| rumsey.path_in_bundle f } }
    let(:dirs) { %w(cb837cp4412 cm057cr1745 cp898cs9946).map { |d| rumsey.path_in_bundle d } }

    it "finds expected files with correct relative paths" do
      tests = [
        # Stageables.    Expected relative paths.                 Type of item as stageables.
        [files,         fs.map { |f| File.basename f }], # Files.
        [dirs,          fs], # Directories.
        [rumsey.bundle_dir, fs.map { |f| File.join(File.basename(rumsey.bundle_dir), f) }], # Even higher directory.
      ]
      tests.each do |stageables, exp_relative_paths|
        # Full paths of object files should never change, but the relative paths varies, depending on the stageables.
        ofiles = rumsey.discover_object_files(stageables)
        expect(ofiles.map(&:path)).to eq(files)
        expect(ofiles.map(&:relative_path)).to eq(exp_relative_paths)
      end
    end
  end

  describe "object discovery: other" do
    describe '#actual_container' do
      it 'returns expected paths switched by :use_container flag' do
        path = "foo/bar/x.tif"
        revs.stageable_discovery[:use_container] = false # Return the container unmodified.
        expect(revs.actual_container(path)).to eq(path)
        revs.stageable_discovery[:use_container] = true # Adjust the container value.
        expect(revs.actual_container(path)).to eq('foo/bar')
      end
    end

    it "is able to exercise all_object_files()" do
      fake_files = [[1, 2], [3, 4], [5, 6]]
      fake_dobjs = fake_files.map { |fs| double('dobj', :object_files => fs) }
      revs.digital_objects = fake_dobjs
      expect(revs.all_object_files).to eq(fake_files.flatten)
    end

    it "new_object_file() should return an ObjectFile with expected path values" do
      allow(revs).to receive(:exclude_from_path).and_return(false)
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
        ofile = revs.new_object_file t[:stageable], t[:file_path]
        expect(ofile).to be_a(PreAssembly::ObjectFile)
        expect(ofile.path).to          eq(t[:file_path])
        expect(ofile.relative_path).to eq(t[:exp_rel_path])
      end
    end

    it "exclude_from_content() should behave correctly" do
      expect(rumsey.exclude_from_content(rumsey.path_in_bundle('image1.tif'))).to be_falsey
      expect(rumsey.exclude_from_content(rumsey.path_in_bundle('descMetadata.xml'))).to be_truthy
    end
  end

  describe '#load_checksums' do
    it "loads checksums and attach them to the ObjectFiles" do
      rumsey.discover_objects
      rumsey.all_object_files.each { |f|    expect(f.checksum).to be_nil }
      rumsey.digital_objects.each  { |dobj| rumsey.load_checksums(dobj) }
      rumsey.all_object_files.each { |f|    expect(f.checksum).to match(md5_regex) }
    end
  end

  describe '#load_provider_checksums' do
    it "does nothing when no checksums file is present" do
      expect(rumsey).not_to receive(:read_exp_checksums)
      rumsey.load_provider_checksums
    end

    it "empty string yields no checksums" do
      allow(revs).to receive(:read_exp_checksums).and_return('')
      revs.load_provider_checksums
      expect(revs.provider_checksums).to eq({})
    end

    it "checksums are parsed correctly" do
      checksum_data = {
        'foo1.tif' => '4e3cd24dd79f3ec91622d9f8e5ab5afa',
        'foo2.tif' => '7e40beb08d646044529b9138a5f1c796',
        'foo3.tif' => 'e5263af3ebb27d4ab44f70317cb249c1',
        'foo4.tif' => '15263af3ebb27d4ab44f74316cb249a4',
      }
      checksum_string = checksum_data.map { |f, c| "MD5 (#{f}) = #{c}\n" }.join ''
      allow(revs).to receive(:read_exp_checksums).and_return(checksum_string)
      revs.load_provider_checksums
      expect(revs.provider_checksums).to eq(checksum_data)
    end
  end

  context "checksums: retrieving and computing" do
    let(:file_path) { revs.path_in_bundle 'image1.tif' }
    let(:file) { Assembly::ObjectFile.new(file_path) }

    describe '#retrieve_checksum' do
      it "returns provider checksum when it is available" do
        fake_md5 = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
        revs.provider_checksums = { file_path => fake_md5 }
        expect(revs).not_to receive(:compute_checksum)
        expect(revs.retrieve_checksum(file)).to eq(fake_md5)
      end
    end

    describe '#retrieve_checksum' do
      it "computes checksum when checksum is not available" do
        revs.provider_checksums = {}
        expect(revs).to receive(:compute_checksum)
        revs.retrieve_checksum(file)
      end
    end

    describe '#compute_checksum' do
      it "returns nil if @compute_checksum is false" do
        revs.compute_checksum = false
        expect(revs.compute_checksum(file)).to be_nil
      end

      it "returns an md5 checksum" do
        expect(revs.compute_checksum(file)).to be_a(String).and match(md5_regex)
      end
    end
  end

  describe '#process_manifest' do
    it "does nothing for bundles that do not use a manifest" do
      rumsey.discover_objects
      expect(rumsey).not_to receive :manifest_rows
      rumsey.process_manifest
    end

    it "augments the digital objects with additional information" do
      # Discover the objects: we should find some.
      revs.discover_objects
      expect(revs.digital_objects.size).to eq(3)
      # Before processing manifest: various attributes should be nil or default value.
      revs.digital_objects.each do |dobj|
        expect(dobj.label).to        eq(Dor::Config.dor.default_label)
        expect(dobj.source_id).to    be_nil
        expect(dobj.manifest_row).to be_nil
      end
      # And now those attributes should have content.
      revs.process_manifest
      revs.digital_objects.each do |dobj|
        expect(dobj.label).to be_a(String)
        expect(dobj.label).not_to eq(Dor::Config.dor.default_label)
        expect(dobj.source_id).to be_a(String)
        expect(dobj.manifest_row).to be_a(Hash)
      end
    end
  end

  describe '#manifest_rows' do
    it "loads the manifest CSV only once, during the validation phase, and return all three rows even if you access the manifest multiple times" do
      expect(revs).not_to receive(:load_manifest_rows_from_csv)
      3.times { revs.manifest_rows.size == 3 }
    end

    it "returns empty array for bundles that do not use a manifest" do
      expect(rumsey.manifest_rows).to eq([])
    end
  end

  describe '#validate_files' do
    before { rumsey.discover_objects }

    it "returns expected tally if all images are valid" do
      skip "validate_files has depedencies on exiftool, making it sometimes incorrectly fail...it basically exercises methods already adequately tested in the assembly-objectfile gem"
      rumsey.digital_objects.each do |dobj|
        expect(rumsey.validate_files(dobj)).to eq({ :valid => 1, :skipped => 1 })
      end
    end

    it "raises exception if one of the object files is an invalid image" do
      # Create a double that will simulate an invalid image.
      img_params = { :image? => true, :valid_image? => false, :path => 'bad/image.tif' }
      bad_image  = double 'bad_image', img_params
      # Check for exceptions.
      exp_msg    = /^File validation failed/
      rumsey.digital_objects.each do |dobj|
        dobj.object_files = [bad_image]
        expect { rumsey.validate_files(dobj) }.to raise_error(exp_msg)
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
      revs.discover_objects
      revs.skippables = {}
      expect(revs.objects_to_process).to eq(revs.digital_objects)
    end

    it "returns a filtered list of digital objects" do
      revs.discover_objects
      revs.skippables = {}
      revs.skippables[revs.digital_objects[-1].unadjusted_container] = true
      o2p = revs.objects_to_process
      expect(o2p.size).to eq(revs.digital_objects.size - 1)
      expect(o2p).to eq(revs.digital_objects[0..-2])
    end
  end

  describe '#setup_paths and defaults' do
    it "sets the staging_dir to the value specified in YAML" do
      revs.setup_paths
      expect(revs.staging_dir).to eq('tmp')
    end

    it "sets the progress log file to match the input yaml file if no progress log is specified in YAML" do
      b = bundle_setup(:proj_sohp3)
      b.setup_paths
      expect(b.progress_log_file).to eq('spec/test_data/project_config_files/proj_sohp3_progress.yaml')
    end

    it "sets the content_tag_override to the default value when not specified" do
      expect(revs.project_style[:content_tag_override]).to be_falsey
      expect(@ps['project_style'][:content_tag_override]).to be_nil
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
      revs.discover_objects
      dobj = revs.digital_objects[0]
      exp = {
        :unadjusted_container => dobj.unadjusted_container,
        :pid                  => dobj.pid,
        :pre_assem_finished   => dobj.pre_assem_finished,
        :timestamp            => Time.now.strftime('%Y-%m-%d %H:%I:%S')
      }
      expect(revs.log_progress_info(dobj)).to eq(exp)
    end
  end

  describe "#delete_digital_objects" do
    before { revs.digital_objects = [] }

    it "does nothing if @cleanup == false" do
      revs.cleanup = false
      expect(revs.digital_objects).not_to receive :each
      revs.delete_digital_objects
    end

    it "does something if @cleanup == true" do
      revs.cleanup = true
      expect(revs.digital_objects).to receive :each
      revs.delete_digital_objects
    end
  end

  describe "file and directory utilities" do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { revs.path_in_bundle(relative) }

    it "#path_in_bundle returns expected value" do
      expect(revs.path_in_bundle(relative)).to eq('spec/test_data/bundle_input_a/abc/def.jpg')
    end

    it "#relative_path returns expected value" do
      expect(revs.relative_path(revs.bundle_dir, full)).to eq(relative)
    end

    it "#relative_path raises error if given bogus arguments" do
      path = "foo/bar/fubb.txt"
      exp_msg = /^Bad args to relative_path/
      expect { revs.relative_path('',   path) }.to raise_error(ArgumentError, exp_msg)
      expect { revs.relative_path(path, path) }.to raise_error(ArgumentError, exp_msg)
      expect { revs.relative_path('xx', path) }.to raise_error(ArgumentError, exp_msg)
    end

    it "#get_base_dir returns expected value" do
      expect(revs.get_base_dir('foo/bar/fubb.txt')).to eq('foo/bar')
    end

    it "#get_base_dir raises error if given bogus arguments" do
      exp_msg  = /^Bad arg to get_base_dir/
      bad_args = ['foo.txt', '', 'x\y\foo.txt']
      bad_args.each do |arg|
        expect { revs.get_base_dir(arg) }.to raise_error(ArgumentError, exp_msg)
      end
    end

    it "#dir_glob returns expected information" do
      exp = [1, 2, 3].map { |n| revs.path_in_bundle "image#{n}.tif" }
      expect(revs.dir_glob(revs.path_in_bundle "*.tif")).to eq(exp)
    end

    it "#find_files_recursively returns expected information" do
      {
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
      }.each do |proj, files|
        b = bundle_setup(proj)
        exp_files = files.map { |f| b.path_in_bundle f }
        expect(b.find_files_recursively(b.bundle_dir).sort).to eq(exp_files)
      end
    end
  end

  describe "misc utilities" do
    it '#source_id_suffix is empty if not making unique source IDs' do
      revs.uniqify_source_ids = false
      expect(revs.source_id_suffix).to eq('')
    end

    it '#source_id_suffix looks like an integer if making unique source IDs' do
      revs.uniqify_source_ids = true
      expect(revs.source_id_suffix).to match(/^_\d+$/)
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
