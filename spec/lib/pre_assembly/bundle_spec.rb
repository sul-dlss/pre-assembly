RSpec.describe PreAssembly::Bundle do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }
  let(:flat_dir_images) { bundle_setup(:flat_dir_images) }
  let(:images_jp2_tif) { bundle_setup(:images_jp2_tif) }
  let(:multimedia) { bundle_setup(:multimedia) }
  let(:b) { create(:bundle_context_with_deleted_output_dir).bundle }

  after { FileUtils.rm_rf(b.bundle_context.output_dir) if Dir.exist?(b.bundle_context.output_dir) } # cleanup

  describe '#run_pre_assembly' do
    before do
      allow(b).to receive(:process_digital_objects) # stub expensive call
      allow(b).to receive(:log) # log statements we don't care about here
    end

    it 'returns processed_pids' do
      allow(b).to receive(:processed_pids).and_return ['druid:aa111aa1111', 'druid:bb222bb2222']
      expect(b.run_pre_assembly).to eq ['druid:aa111aa1111', 'druid:bb222bb2222']
    end
    it 'logs the start and finish of the run' do
      expect(b).to receive(:log).with("\nstarting run_pre_assembly(#{b.run_log_msg})")
      expect(b).to receive(:log).with("\nfinishing run_pre_assembly(#{b.run_log_msg})")
      b.run_pre_assembly
    end
    it 'calls process_digital_objects' do
      expect(b).to receive(:process_digital_objects)
      b.run_pre_assembly
    end
  end

  describe '#process_digital_objects' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true, close: true) }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }

    before do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:initialize_assembly_workflow)
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
      allow(Dor::Item).to receive(:find).with(any_args)
    end

    it 'runs cleanly for new objects' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:'openable?').and_return(false)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(1)
      expect { b.process_digital_objects }.not_to raise_error
    end

    it 'runs cleanly for re-accessioned objects that are ready to be versioned' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:'openable?').and_return(true)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(2)
      expect { b.process_digital_objects }.not_to raise_error
    end

    it 'throws an exception for re-accessioned objects that are not ready to be versioned' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:'openable?').and_return(false)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(2)
      exp_msg = "druid:aa111aa1111 can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened"
      expect { b.process_digital_objects }.to raise_error(RuntimeError, exp_msg)
    end
  end

  describe '#load_skippables' do
    it 'returns expected hash of skippable items' do
      allow(multimedia).to receive(:progress_log_file).and_return('spec/test_data/input/mock_progress_log.yaml')
      expect(multimedia.skippables).to eq({})
      multimedia.load_skippables
      expect(multimedia.skippables).to eq('aa' => true, 'bb' => true)
    end
  end

  describe '#run_log_msg' do
    it 'returns a string' do
      expect(flat_dir_images.run_log_msg).to be_a(String)
    end

    it 'returns a string with the expected values' do
      expect(flat_dir_images.run_log_msg).to match(/content_structure="#{flat_dir_images.content_structure}"/)
      expect(flat_dir_images.run_log_msg).to match(/project_name="#{flat_dir_images.project_name}"/)
      expect(flat_dir_images.run_log_msg).to match(/bundle_dir="#{flat_dir_images.bundle_dir}"/)
      expect(flat_dir_images.run_log_msg).to match(/assembly_staging_dir="#{Settings.assembly_staging_dir}"/)
      expect(flat_dir_images.run_log_msg).to match(/environment="test"/)
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
      expect(multimedia.digital_objects.first.container.size).to be > multimedia.bundle_dir.size
    end
  end

  describe '#load_checksums' do
    it 'loads checksums and attach them to the ObjectFiles' do
      multimedia.send(:all_object_files).each { |f| expect(f.checksum).to be_nil }
      multimedia.digital_objects.each { |dobj| multimedia.load_checksums(dobj) }
      multimedia.send(:all_object_files).each { |f| expect(f.checksum).to match(md5_regex) }
    end
  end

  describe '#digital_objects' do
    it 'augments the digital objects with additional information' do
      expect(flat_dir_images.digital_objects.size).to eq(3)
      flat_dir_images.digital_objects.each do |dobj|
        expect(dobj.label).to be_a(String)
        expect(dobj.label).not_to eq('Unknown') # hardcoded in class
        expect(dobj.source_id).to be_a(String)
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

  ### Private methods

  describe '#discover_containers_via_manifest' do
    it 'returns expected information' do
      vals = %w[123.tif 456.tif 789.tif]
      allow(flat_dir_images).to receive(:manifest_rows).and_return(vals.map { |v| { object: v } })
      expect(flat_dir_images.send(:discover_containers_via_manifest)).to eq(vals.map { |v| flat_dir_images.path_in_bundle v })
    end
  end

  describe '#discover_items_via_crawl' do
    it 'returns expected information' do
      items = %w[abc.txt def.txt ghi.txt 123.tif 456.tif 456.TIF].map { |i| flat_dir_images.path_in_bundle i }
      allow(flat_dir_images).to receive(:dir_glob).and_return(items)
      expect(flat_dir_images.send(:discover_items_via_crawl, flat_dir_images.bundle_dir)).to eq(items.sort)
    end
  end

  describe '#discover_object_files' do
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

    it 'finds expected files with correct relative paths from files' do
      ofiles = images_jp2_tif.send(:discover_object_files, files)
      expect(ofiles.map(&:path)).to eq(files)
      expect(ofiles.map(&:relative_path)).to eq(fs.map { |f| File.basename f })
    end
    it 'finds expected files with correct relative paths from dirs' do
      ofiles = images_jp2_tif.send(:discover_object_files, dirs)
      expect(ofiles.map(&:path)).to eq(files)
      expect(ofiles.map(&:relative_path)).to eq(fs)
    end
  end

  describe '#new_object_file' do
    it 'returns an ObjectFile with expected path values' do
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
        ofile = flat_dir_images.send(:new_object_file, t[:stageable], t[:file_path])
        expect(ofile).to be_a(PreAssembly::ObjectFile)
        expect(ofile.path).to          eq(t[:file_path])
        expect(ofile.relative_path).to eq(t[:exp_rel_path])
      end
    end
  end

  describe '#exclude_from_content' do
    it 'behaves correctly' do
      skip 'web app does not need to support exclude_from_content'
      expect(multimedia.send(:exclude_from_content, multimedia.path_in_bundle('image1.tif'))).to be_falsey
      expect(multimedia.send(:exclude_from_content, multimedia.path_in_bundle('descMetadata.xml'))).to be_truthy
    end
  end

  describe '#all_object_files' do
    it 'returns Array of object_files from all DigitalObjects' do
      fake_files = [[1, 2], [3, 4], [5, 6]]
      fake_dobjs = fake_files.map { |fs| instance_double(PreAssembly::DigitalObject, object_files: fs) }
      flat_dir_images.digital_objects = fake_dobjs
      expect(flat_dir_images.send(:all_object_files)).to eq(fake_files.flatten)
    end
  end

  describe '#get_base_dir' do
    it 'returns expected value' do
      expect(flat_dir_images.send(:get_base_dir, 'foo/bar/fubb.txt')).to eq('foo/bar')
    end
    it 'raises error if given bogus arguments' do
      exp_msg = /^Bad arg to get_base_dir/
      expect { flat_dir_images.send(:get_base_dir, 'foo.txt')     }.to raise_error(ArgumentError, exp_msg)
      expect { flat_dir_images.send(:get_base_dir, '')            }.to raise_error(ArgumentError, exp_msg)
      expect { flat_dir_images.send(:get_base_dir, 'x\y\foo.txt') }.to raise_error(ArgumentError, exp_msg)
    end
  end

  describe '#dir_glob' do
    it ' returns expected information' do
      exp = [1, 2, 3].map { |n| flat_dir_images.path_in_bundle "image#{n}.tif" }
      expect(flat_dir_images.send(:dir_glob, flat_dir_images.path_in_bundle('*.tif'))).to eq(exp)
    end
  end

  describe 'file and directory utilities' do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { flat_dir_images.path_in_bundle(relative) }

    it '#path_in_bundle returns expected value' do
      expect(flat_dir_images.path_in_bundle(relative)).to eq('spec/test_data/flat_dir_images/abc/def.jpg')
    end
    it '#relative_path returns expected value' do
      expect(flat_dir_images.send(:relative_path, flat_dir_images.bundle_dir, full)).to eq(relative)
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
        expect(b.send(:find_files_recursively, b.bundle_dir).sort).to eq(exp_files)
      end
    end
  end
end
