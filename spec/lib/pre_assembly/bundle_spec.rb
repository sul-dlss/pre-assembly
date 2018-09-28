RSpec.describe PreAssembly::Bundle do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }
  let(:flat_dir_images) { bundle_setup(:flat_dir_images) }
  let(:images_jp2_tif) { bundle_setup(:images_jp2_tif) }
  let(:smpl_multimedia) { bundle_setup(:smpl_multimedia) }

  describe '#run_pre_assembly' do
    let(:exp_workflow_svc_url) { Regexp.new("^#{Dor::Config.dor_services.url}/objects/.*/apo_workflows/assemblyWF$") }

    before do
      allow(RestClient).to receive(:post)
        .with(a_string_matching(exp_workflow_svc_url), {})
        .and_return(instance_double(RestClient::Response, code: 200))
      allow(Dor::Item).to receive(:find).with(any_args)
    end

    it 'runs images_jp2_tif cleanly using images_jp2_tif.yaml for options' do
      bc = bundle_context_from_hash('images_jp2_tif')
      # need to delete progress log to ensure this test doesn't skip objects already run
      FileUtils.rm_rf(bc.output_dir) if Dir.exist?(bc.output_dir)
      bc.save
      b = described_class.new bc
      pids = []
      expect { pids = b.run_pre_assembly }.not_to raise_error
      expect(pids).to eq ['druid:jy812bp9403', 'druid:tz250tk7584', 'druid:gn330dv6119']
    end
  end

  describe '#load_skippables' do
    it 'returns expected hash of skippable items' do
      allow(smpl_multimedia).to receive(:progress_log_file).and_return('spec/test_data/input/mock_progress_log.yaml')
      expect(smpl_multimedia.skippables).to eq({})
      smpl_multimedia.load_skippables
      expect(smpl_multimedia.skippables).to eq('aa' => true, 'bb' => true)
    end
  end

  describe '#run_log_msg' do
    it 'returns a string' do
      expect(flat_dir_images.run_log_msg).to be_a(String)
    end
  end

  describe '#processed_pids' do
    it 'pulls pids from digital_objects' do
      exp_pids = [11, 22, 33]
      flat_dir_images.digital_objects = exp_pids.map { |p| instance_double(PreAssembly::DigitalObject, pid: p) }
      expect(flat_dir_images.processed_pids).to eq(exp_pids)
    end
  end

  describe '#digital_objects' do
    it 'finds the correct number of objects' do
      b = bundle_setup(:folder_manifest)
      expect(b.digital_objects.size).to eq(3)
    end

    it 'handles containers correctly' do
      expect(smpl_multimedia.digital_objects.first.container.size).to be > smpl_multimedia.bundle_dir.size
    end
  end

  describe '#object_discovery: discovery via manifest and crawl' do
    it 'discover_containers_via_manifest() should return expected information' do
      vals = %w[123.tif 456.tif 789.tif]
      allow(flat_dir_images).to receive(:manifest_rows).and_return(vals.map { |v| { object: v } })
      expect(flat_dir_images.discover_containers_via_manifest).to eq(vals.map { |v| flat_dir_images.path_in_bundle v })
    end

    it '#discover_items_via_crawl should return expected information' do
      items = %w[abc.txt def.txt ghi.txt 123.tif 456.tif 456.TIF].map { |i| flat_dir_images.path_in_bundle i }
      allow(flat_dir_images).to receive(:dir_glob).and_return(items)
      expect(flat_dir_images.discover_items_via_crawl(flat_dir_images.bundle_dir)).to eq(items.sort)
    end
  end

  describe 'object discovery: #discover_object_files' do
    let(:fs) do
      %w[
        gn330dv6119/image1.jp2
        gn330dv6119/image1.tif
        gn330dv6119/image2.jp2
        gn330dv6119/image2.tif
        jy812bp9403/00/image1.tif
        jy812bp9403/00/image2.tif
        jy812bp9403/05/image1.jp2
        tz250tk7584/00/image1.tif
        tz250tk7584/00/image2.tif
      ]
    end
    let(:files) { fs.map { |f| images_jp2_tif.path_in_bundle f } }
    let(:dirs) { %w[gn330dv6119 jy812bp9403 tz250tk7584].map { |d| images_jp2_tif.path_in_bundle d } }

    it 'finds expected files with correct relative paths' do
      tests = [
        # Stageables.    Expected relative paths.                 Type of item as stageables.
        [files,         fs.map { |f| File.basename f }], # Files.
        [dirs,          fs], # Directories.
        # note: the following line fails because we now require manifest file to be in the directory
        # [images_jp2_tif.bundle_dir, fs.map { |f| File.join(File.basename(images_jp2_tif.bundle_dir), f) }], # Even higher directory.
      ]
      tests.each do |stageables, exp_relative_paths|
        # Full paths of object files should never change, but the relative paths varies, depending on the stageables.
        ofiles = images_jp2_tif.discover_object_files(stageables)
        expect(ofiles.map(&:path)).to eq(files)
        expect(ofiles.map(&:relative_path)).to eq(exp_relative_paths)
      end
    end
  end

  describe 'object discovery: other' do
    it 'is able to exercise all_object_files()' do
      fake_files = [[1, 2], [3, 4], [5, 6]]
      fake_dobjs = fake_files.map { |fs| instance_double(PreAssembly::DigitalObject, object_files: fs) }
      flat_dir_images.digital_objects = fake_dobjs
      expect(flat_dir_images.all_object_files).to eq(fake_files.flatten)
    end

    it 'new_object_file() should return an ObjectFile with expected path values' do
      allow(flat_dir_images).to receive(:exclude_from_content).and_return(false)
      tests = [
        # Stageable is a file:
        # - immediately in bundle dir.
        { stageable: 'BUNDLE/x.tif',
          file_path: 'BUNDLE/x.tif',
          exp_rel_path: 'x.tif' },
        # - within subdir of bundle dir.
        { stageable: 'BUNDLE/a/b/x.tif',
          file_path: 'BUNDLE/a/b/x.tif',
          exp_rel_path: 'x.tif' },
        # Stageable is a directory:
        # - immediately in bundle dir
        { stageable: 'BUNDLE/a',
          file_path: 'BUNDLE/a/x.tif',
          exp_rel_path: 'a/x.tif' },
        # - immediately in bundle dir, with file deeper
        { stageable: 'BUNDLE/a',
          file_path: 'BUNDLE/a/b/x.tif',
          exp_rel_path: 'a/b/x.tif' },
        # - within a subdir of bundle dir
        { stageable: 'BUNDLE/a/b',
          file_path: 'BUNDLE/a/b/x.tif',
          exp_rel_path: 'b/x.tif' },
        # - within a subdir of bundle dir, with file deeper
        { stageable: 'BUNDLE/a/b',
          file_path: 'BUNDLE/a/b/c/d/x.tif',
          exp_rel_path: 'b/c/d/x.tif' }
      ]
      tests.each do |t|
        ofile = flat_dir_images.new_object_file t[:stageable], t[:file_path]
        expect(ofile).to be_a(PreAssembly::ObjectFile)
        expect(ofile.path).to          eq(t[:file_path])
        expect(ofile.relative_path).to eq(t[:exp_rel_path])
      end
    end

    it 'exclude_from_content() should behave correctly' do
      skip 'web app does not need to support exclude_from_content'
      expect(smpl_multimedia.exclude_from_content(smpl_multimedia.path_in_bundle('image1.tif'))).to be_falsey
      expect(smpl_multimedia.exclude_from_content(smpl_multimedia.path_in_bundle('descMetadata.xml'))).to be_truthy
    end
  end

  describe '#load_checksums' do
    it 'loads checksums and attach them to the ObjectFiles' do
      smpl_multimedia.all_object_files.each { |f| expect(f.checksum).to be_nil }
      smpl_multimedia.digital_objects.each { |dobj| smpl_multimedia.load_checksums(dobj) }
      smpl_multimedia.all_object_files.each { |f| expect(f.checksum).to match(md5_regex) }
    end
  end

  describe '#digital_objects' do
    it 'augments the digital objects with additional information' do
      expect(flat_dir_images.digital_objects.size).to eq(3)
      flat_dir_images.digital_objects.each do |dobj|
        expect(dobj.label).to be_a(String)
        expect(dobj.label).not_to eq('Unknown') # hardcoded in class
        expect(dobj.source_id).to be_a(String)
        expect(dobj.manifest_row).to be_a(Hash)
      end
    end
  end

  describe '#objects_to_process' do
    it 'returns all objects if there are no skippables' do
      flat_dir_images.skippables = {}
      expect(flat_dir_images.objects_to_process).to eq(flat_dir_images.digital_objects)
    end

    it 'returns a filtered list of digital objects' do
      flat_dir_images.skippables = {}
      flat_dir_images.skippables[flat_dir_images.digital_objects.last.container] = true
      o2p = flat_dir_images.objects_to_process
      expect(o2p.size).to eq(flat_dir_images.digital_objects.size - 1)
      expect(o2p).to eq(flat_dir_images.digital_objects[0..-2])
    end
  end

  describe '#log_progress_info' do
    it 'returns expected info about a digital object' do
      dobj = flat_dir_images.digital_objects[0]
      exp = {
        container: dobj.container,
        pid: dobj.pid,
        pre_assem_finished: dobj.pre_assem_finished,
        timestamp: Time.now.strftime('%Y-%m-%d %H:%I:%S')
      }
      expect(flat_dir_images.log_progress_info(dobj)).to eq(exp)
    end
  end

  describe 'file and directory utilities' do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { flat_dir_images.path_in_bundle(relative) }

    it '#path_in_bundle returns expected value' do
      expect(flat_dir_images.path_in_bundle(relative)).to eq('spec/test_data/flat_dir_images/abc/def.jpg')
    end
    it '#relative_path returns expected value' do
      expect(flat_dir_images.relative_path(flat_dir_images.bundle_dir, full)).to eq(relative)
    end
    it '#get_base_dir returns expected value' do
      expect(flat_dir_images.get_base_dir('foo/bar/fubb.txt')).to eq('foo/bar')
    end

    it '#get_base_dir raises error if given bogus arguments' do
      exp_msg  = /^Bad arg to get_base_dir/
      bad_args = ['foo.txt', '', 'x\y\foo.txt']
      bad_args.each do |arg|
        expect { flat_dir_images.get_base_dir(arg) }.to raise_error(ArgumentError, exp_msg)
      end
    end

    it '#dir_glob returns expected information' do
      exp = [1, 2, 3].map { |n| flat_dir_images.path_in_bundle "image#{n}.tif" }
      expect(flat_dir_images.dir_glob(flat_dir_images.path_in_bundle('*.tif'))).to eq(exp)
    end

    it '#find_files_recursively returns expected information' do
      {
        flat_dir_images: [
          'checksums.txt',
          'image1.tif',
          'image2.tif',
          'image3.tif',
          'manifest.csv',
          'manifest_badsourceid_column.csv'
        ],
        images_jp2_tif: [
          'gn330dv6119/image1.jp2',
          'gn330dv6119/image1.tif',
          'gn330dv6119/image2.jp2',
          'gn330dv6119/image2.tif',
          'jy812bp9403/00/image1.tif',
          'jy812bp9403/00/image2.tif',
          'jy812bp9403/05/image1.jp2',
          'manifest.csv',
          'tz250tk7584/00/image1.tif',
          'tz250tk7584/00/image2.tif'
        ]
      }.each do |proj, files|
        b = described_class.new(bundle_context_from_hash(proj))
        exp_files = files.map { |f| b.path_in_bundle f }
        expect(b.find_files_recursively(b.bundle_dir).sort).to eq(exp_files)
      end
    end
  end
end
