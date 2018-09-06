RSpec.describe PreAssembly::Bundle do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }
  let(:revs_context) { context_from_proj(:proj_revs) }
  let(:rumsey_context) do
    context_from_proj(:proj_rumsey).tap do |c|
      c.manifest_cols[:object_container] = 'folder'
      allow(c).to receive(:manifest).and_return('spec/test_data/bundle_input_e/manifest_of_3.csv')
    end
  end
  let(:revs) { described_class.new(revs_context) }
  let(:rumsey) { described_class.new(rumsey_context) }

  before do
    allow_any_instance_of(BundleContextTemporary).to receive(:validate_usage) # replace w/ AR validation
  end

  describe '#run_pre_assembly' do
    let(:exp_workflow_svc_url) { Regexp.new("^#{Dor::Config.dor_services.url}/objects/.*/apo_workflows/assemblyWF$") }
    before do
      allow(RestClient).to receive(:post).with(a_string_matching(exp_workflow_svc_url), {}).and_return(instance_double(RestClient::Response, code: 200))
    end
    it 'runs cleanly using smoke_test.yaml for options' do
      # TODO: as we switch to using models (#172, #175, etc) this test should also switch
      bc = context_from_proj('smoke_test')
      # need to delete progress log to ensure this test doesn't skip objects already run
      File.delete(bc.user_params[:progress_log_file]) if File.exist?(bc.user_params[:progress_log_file])
      pids = []
      expect {
        b = PreAssembly::Bundle.new bc
        pids = b.run_pre_assembly
      }.not_to raise_error
      expect(pids).to eq ["druid:jy812bp9403", "druid:tz250tk7584", "druid:gn330dv6119"]
    end
  end

  describe '#load_skippables' do
    it "returns expected hash of skippable items" do
      allow(rumsey).to receive(:progress_log_file).and_return('spec/test_data/input/mock_progress_log.yaml')
      expect(rumsey.skippables).to eq({})
      rumsey.load_skippables
      expect(rumsey.skippables).to eq({ "aa" => true, "bb" => true })
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
      expect(manifest).to all(be_an(ActiveSupport::HashWithIndifferentAccess)) # accessible w/ string and symbols
      expect(manifest).to all(include(*headers))
      expect(manifest[0][:description]).to be_nil
      expect(manifest[1][:description]).to eq('')
      expect(manifest[2][:description]).to eq('yo, this is a description')
    end
  end

  describe '#run_log_msg' do
    it 'returns a string' do
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

  describe '#digital_objects' do
    it "finds the correct number of objects" do
      b = bundle_setup(:folder_manifest)
      expect(b.digital_objects.size).to eq(3)
    end

    it "handles containers correctly" do
      expect(rumsey.digital_objects.first.container.size).to be > rumsey.bundle_dir.size
    end
  end

  describe '#object_discovery: discovery via manifest and crawl' do
    it "discover_containers_via_manifest() should return expected information" do
      vals = %w(123.tif 456.tif 789.tif)
      revs.manifest_cols[:object_container] = :col_foo
      allow(revs).to receive(:manifest_rows).and_return(vals.map { |v| { col_foo: v } })
      expect(revs.discover_containers_via_manifest).to eq(vals.map { |v| revs.path_in_bundle v })
    end

    it '#discover_items_via_crawl should return expected information' do
      items = %w[abc.txt def.txt ghi.txt 123.tif 456.tif 456.TIF].map { |i| revs.path_in_bundle i }
      allow(revs).to receive(:dir_glob).and_return(items)
      expect(revs.discover_items_via_crawl(revs.bundle_dir)).to eq(items.sort)
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
    it "is able to exercise all_object_files()" do
      fake_files = [[1, 2], [3, 4], [5, 6]]
      fake_dobjs = fake_files.map { |fs| double('dobj', :object_files => fs) }
      revs.digital_objects = fake_dobjs
      expect(revs.all_object_files).to eq(fake_files.flatten)
    end

    it "new_object_file() should return an ObjectFile with expected path values" do
      allow(revs).to receive(:exclude_from_content).and_return(false)
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
      rumsey.all_object_files.each { |f|    expect(f.checksum).to be_nil }
      rumsey.digital_objects.each  { |dobj| rumsey.load_checksums(dobj) }
      rumsey.all_object_files.each { |f|    expect(f.checksum).to match(md5_regex) }
    end
  end

  describe '#digital_objects' do
    it "augments the digital objects with additional information" do
      expect(revs.digital_objects.size).to eq(3)
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
      expect(revs.manifest_rows.size).to eq 3
      expect(described_class).not_to receive(:import_csv)
      revs.manifest_rows
    end
  end

  describe '#validate_files' do
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
      b = described_class.new(context_from_proj(:proj_sohp3))
      b.bundle_context.manifest_cols[:object_container] = 'folder'
      allow(b.bundle_context).to receive(:manifest).and_return('spec/test_data/bundle_input_e/manifest_of_3.csv')
      expect(b.digital_objects.size).to eq(3)
      expect(b.objects_to_process.size).to eq(1)
    end

    it "has the correct list of objects to accession if specified with except option" do
      b = described_class.new(context_from_proj(:proj_sohp4)) # has 2 except listings
      b.bundle_context.manifest_cols[:object_container] = 'folder'
      allow(b.bundle_context).to receive(:manifest).and_return('spec/test_data/bundle_input_e/manifest_of_3.csv')
      expect(b.digital_objects.size).to eq(3)
      expect(b.objects_to_process.size).to eq(1)
    end

    it "returns all objects if there are no skippables" do
      revs.skippables = {}
      expect(revs.objects_to_process).to eq(revs.digital_objects)
    end

    it "returns a filtered list of digital objects" do
      revs.skippables = {}
      revs.skippables[revs.digital_objects[-1].unadjusted_container] = true
      o2p = revs.objects_to_process
      expect(o2p.size).to eq(revs.digital_objects.size - 1)
      expect(o2p).to eq(revs.digital_objects[0..-2])
    end
  end

  describe "#log_progress_info" do
    it "returns expected info about a digital object" do
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

  describe "file and directory utilities" do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { revs.path_in_bundle(relative) }

    it "#path_in_bundle returns expected value" do
      expect(revs.path_in_bundle(relative)).to eq('spec/test_data/bundle_input_a/abc/def.jpg')
    end
    it "#relative_path returns expected value" do
      expect(revs.relative_path(revs.bundle_dir, full)).to eq(relative)
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
        b = described_class.new(context_from_proj(proj))
        exp_files = files.map { |f| b.path_in_bundle f }
        expect(b.find_files_recursively(b.bundle_dir).sort).to eq(exp_files)
      end
    end
  end
end
