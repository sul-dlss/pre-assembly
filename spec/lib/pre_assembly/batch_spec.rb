# frozen_string_literal: true

RSpec.describe PreAssembly::Batch do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }
  let(:flat_dir_images) { batch_setup(:flat_dir_images) }
  let(:images_jp2_tif) { batch_setup(:images_jp2_tif) }
  let(:multimedia) { batch_setup(:multimedia) }
  let(:batch) { create(:batch_context_with_deleted_output_dir).batch }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, access: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::Vocab.image, access: cocina_model_world_access) }
  let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, find: item) }

  before do
    allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
  end

  after { FileUtils.rm_rf(batch.batch_context.output_dir) if Dir.exist?(batch.batch_context.output_dir) } # cleanup

  describe '#run_pre_assembly' do
    before do
      allow(batch).to receive(:process_digital_objects) # stub expensive call
      allow(batch).to receive(:log) # log statements we don't care about here
    end

    it 'logs the start and finish of the run' do
      expect(batch).to receive(:log).with("\nstarting run_pre_assembly(#{batch.run_log_msg})")
      expect(batch).to receive(:log).with("\nfinishing run_pre_assembly(#{batch.run_log_msg})")
      batch.run_pre_assembly
    end

    it 'calls process_digital_objects' do
      expect(batch).to receive(:process_digital_objects)
      batch.run_pre_assembly
    end
  end

  describe '#process_digital_objects' do
    before do
      allow(StartAccession).to receive(:run)
    end

    it 'runs cleanly for new objects' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(false)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(1)
      expect { batch.process_digital_objects }.not_to raise_error
    end

    it 'runs cleanly for re-accessioned objects that are ready to be versioned' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(true)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(2)
      expect { batch.process_digital_objects }.not_to raise_error
    end

    context 'when there are re-accessioned objects that are not ready to be versioned' do
      before do
        allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(false)
        allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(2)
      end

      let(:yaml) { YAML.load_file(batch.progress_log_file) }

      it 'logs an error' do
        batch.process_digital_objects
        expect(yaml[:status]).to eq 'error'
        expect(yaml[:message]).to eq "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened"
      end
    end

    context 'when there are objects that do not complete pre_assemble' do
      before do
        allow(batch.digital_objects[0]).to receive(:pre_assemble)
        allow(batch.digital_objects[1]).to receive(:pre_assemble)
      end

      let(:yaml) { YAML.load_file(batch.progress_log_file) }

      it 'logs incomplete_status error' do
        batch.process_digital_objects
        expect(yaml[:status]).to eq batch.send(:incomplete_status)[:status]
        expect(yaml[:message]).to eq batch.send(:incomplete_status)[:message]
      end
    end

    context 'when there are dark objects' do
      before do
        allow(batch.digital_objects[0]).to receive(:dark?).and_return(true)
        allow(batch.digital_objects[1]).to receive(:dark?).and_return(false)
        allow(batch.digital_objects[0]).to receive(:pre_assemble)
        allow(batch.digital_objects[1]).to receive(:pre_assemble)
      end

      it 'calls digital_object.pre_assemble with true for the dark objects' do
        batch.process_digital_objects
        expect(batch.digital_objects[0]).to have_received(:pre_assemble).with(true)
        expect(batch.digital_objects[1]).to have_received(:pre_assemble).with(false)
      end
    end

    context 'when batch_context.all_files_public? is true' do
      before do
        allow(batch.batch_context).to receive(:all_files_public?).and_return(true)
        allow(batch.digital_objects[0]).to receive(:pre_assemble)
        allow(batch.digital_objects[1]).to receive(:pre_assemble)
      end

      it 'calls digital_object.pre_assemble with true for all objects' do
        batch.process_digital_objects
        expect(batch.digital_objects[0]).to have_received(:pre_assemble).with(true)
        expect(batch.digital_objects[1]).to have_received(:pre_assemble).with(true)
      end
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

  describe '#digital_objects' do
    let(:batch) { batch_setup(:folder_manifest) }

    it 'finds the correct number of objects' do
      expect(batch.digital_objects.size).to eq(3)
    end

    it 'handles containers correctly' do
      expect(multimedia.digital_objects.first.container.size).to be > multimedia.bundle_dir.size
    end

    it 'augments the digital objects with additional information' do
      expect(flat_dir_images.digital_objects.size).to eq(3)
      flat_dir_images.digital_objects.each do |dobj|
        expect(dobj.label).to be_a(String)
        expect(dobj.label).not_to eq('Unknown') # hardcoded in class
        expect(dobj.source_id).to be_a(String)
      end
    end

    context 'when all_files_public is true' do
      let(:batch_context) do
        build(:batch_context, :folder_manifest, :public_files)
      end
      let(:batch) { described_class.new(batch_context) }

      it 'sets the file attributes to public' do
        batch.digital_objects.each do |dobj|
          dobj.object_files.each do |object_file|
            expect(object_file.file_attributes).to eq(preserve: 'yes', shelve: 'yes', publish: 'yes')
          end
        end
      end
    end

    context 'when object is dark' do
      let(:batch_context) do
        build(:batch_context, :folder_manifest)
      end
      let(:batch) { described_class.new(batch_context) }
      let(:cocina_model_dark_access) { instance_double(Cocina::Models::Access, access: 'dark') }
      let(:dark_item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::Vocab.image, access: cocina_model_dark_access) }
      let(:dsc_object) { instance_double(Dor::Services::Client::Object, find: dark_item) }

      before do
        allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
      end

      it 'sets the file attributes to preserve only' do
        batch.digital_objects.each do |dobj|
          dobj.object_files.each do |object_file|
            expect(object_file.file_attributes).to eq(preserve: 'yes', shelve: 'no', publish: 'no')
          end
        end
      end
    end
  end

  describe '#load_checksums' do
    it 'loads checksums and attach them to the ObjectFiles' do
      multimedia.send(:all_object_files).each { |f| expect(f.checksum).to be_nil }
      multimedia.digital_objects.each { |dobj| multimedia.load_checksums(dobj) }
      multimedia.send(:all_object_files).each { |f| expect(f.checksum).to match(md5_regex) }
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
    subject { flat_dir_images.log_progress_info(progress, status: 'success') }

    let(:dobj) { flat_dir_images.digital_objects[0] }
    let(:progress) { { dobj: dobj } }

    it {
      is_expected.to eq(
        container: progress[:dobj].container,
        pid: progress[:dobj].pid,
        pre_assem_finished: nil,
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        status: 'success'
      )
    }

    it 'uses incomplete_status if no status is passed' do
      expect { flat_dir_images.log_progress_info(progress, nil) }.not_to raise_error(TypeError)
      result = flat_dir_images.log_progress_info(progress, nil)
      expect(result[:status]).to eq batch.send(:incomplete_status)[:status]
      expect(result[:message]).to eq batch.send(:incomplete_status)[:message]
    end
  end

  ### Private methods

  describe '#discover_containers_via_manifest' do
    it 'returns expected information' do
      vals = %w[123.tif 456.tif 789.tif]
      allow(flat_dir_images).to receive(:manifest_rows).and_return(vals.map { |v| { object: v } })
      expect(flat_dir_images.send(:discover_containers_via_manifest)).to eq(vals.map { |v| flat_dir_images.bundle_dir_with_path v })
    end
  end

  describe '#discover_items_via_crawl' do
    it 'returns expected information' do
      items = %w[abc.txt def.txt ghi.txt 123.tif 456.tif 456.TIF].map { |i| flat_dir_images.bundle_dir_with_path i }
      allow(flat_dir_images).to receive(:dir_glob).and_return(items)
      expect(flat_dir_images.send(:discover_items_via_crawl, flat_dir_images.bundle_dir)).to eq(items.sort)
    end
  end

  describe '#exclude_from_content' do
    it 'behaves correctly' do
      skip 'web app does not need to support exclude_from_content'
      expect(multimedia.send(:exclude_from_content, multimedia.bundle_dir_with_path('image1.tif'))).to be_falsey
      expect(multimedia.send(:exclude_from_content, multimedia.bundle_dir_with_path('descMetadata.xml'))).to be_truthy
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

  describe '#dir_glob' do
    it 'returns expected information' do
      exp = [1, 2, 3].map { |n| flat_dir_images.bundle_dir_with_path "image#{n}.tif" }
      expect(flat_dir_images.send(:dir_glob, flat_dir_images.bundle_dir_with_path('*.tif'))).to eq(exp)
    end
  end

  describe 'file and directory utilities' do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { flat_dir_images.bundle_dir_with_path(relative) }

    it '#bundle_dir_with_path returns expected value' do
      expect(flat_dir_images.bundle_dir_with_path(relative)).to eq('spec/test_data/flat_dir_images/abc/def.jpg')
    end

    it '#relative_path returns expected value' do
      expect(flat_dir_images.send(:relative_path, flat_dir_images.bundle_dir, full)).to eq(relative)
    end
  end
end
