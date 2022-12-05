# frozen_string_literal: true

RSpec.describe PreAssembly::Batch do
  let(:md5_regex) { /^[0-9a-f]{32}$/ }
  let(:flat_dir_images) { batch_setup(:flat_dir_images) }
  let(:multimedia) { batch_setup(:multimedia) }
  let(:batch) { create(:batch_context_with_deleted_output_dir).batch }
  let(:dro_access) { { view: 'world' } }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.image).new(access: dro_access)
  end
  let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, find: item, update: true) }
  let(:relative_file_paths) do
    batch.digital_objects.map do |digital_object|
      digital_object.object_files.map(&:relative_path)
    end
  end

  before do
    allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
  end

  after { FileUtils.rm_rf(batch.batch_context.output_dir) } # cleanup

  describe '#run_pre_assembly' do
    before do
      allow(batch).to receive(:pre_assemble_objects) # stub expensive call
      allow(batch).to receive(:log) # log statements we don't care about here
    end

    it 'logs the start and finish of the run' do
      expect(batch).to receive(:log).with("\nstarting run_pre_assembly(#{batch.send(:info_for_log)})")
      expect(batch).to receive(:log).with("\nfinishing run_pre_assembly(#{batch.send(:info_for_log)})")
      batch.run_pre_assembly
    end

    it 'calls pre_assemble_objects' do
      expect(batch).to receive(:pre_assemble_objects)
      batch.run_pre_assembly
    end
  end

  describe '#pre_assemble_objects' do
    before do
      allow(StartAccession).to receive(:run)
    end

    it 'runs cleanly for new objects' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(false)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(1)
      expect(batch.send(:pre_assemble_objects)).to be true
      expect(batch.objects_had_errors).to be false
    end

    it 'runs cleanly for re-accessioned objects that are ready to be versioned' do
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(true)
      allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(2)
      expect(batch.send(:pre_assemble_objects)).to be true
      expect(batch.objects_had_errors).to be false
    end

    context 'when there are re-accessioned objects that are not ready to be versioned' do
      before do
        allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(false)
        allow_any_instance_of(PreAssembly::DigitalObject).to receive(:current_object_version).and_return(2)
      end

      let(:yaml) { YAML.load_file(batch.progress_log_file) }

      it 'indicates errors occured, then logs the error and sets the error message' do
        batch.send(:pre_assemble_objects)
        expect(batch.objects_had_errors).to be true
        expect(batch.error_message).to eq '2 objects had errors during pre-assembly'
        expect(yaml[:status]).to eq 'error'
        expect(yaml[:message]).to eq "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened"
      end
    end

    context 'when there are objects that do not complete pre_assemble' do
      let(:pre_assemble_results) do
        [
          { pre_assem_finished: false, status: 'error', message: 'oops' },
          { pre_assem_finished: true, status: 'success' }
        ].each
      end

      let(:yaml) { YAML.load_stream(File.read(batch.progress_log_file)) }

      before do
        allow(PreAssembly::DigitalObject).to receive(:new).and_wrap_original do |m, *args|
          m.call(*args).tap do |dobj|
            allow(dobj).to receive(:pre_assemble).and_return(pre_assemble_results.next)
          end
        end
      end

      it 'indicates errors occured, then logs the error and sets the error message' do
        batch.send(:pre_assemble_objects)
        expect(batch.objects_had_errors).to be true
        expect(batch.error_message).to eq '1 objects had errors during pre-assembly'
        # first object logs an error
        expect(yaml[0]).to include(status: 'error', message: 'oops', pre_assem_finished: false)
        # second object is a success
        expect(yaml[1]).to include(status: 'success', pre_assem_finished: true)
      end
    end

    context 'when an exception occurs during #pre_assemble' do
      # simulate an exception occurring during pre-assembly of the first object
      let(:stage_files_exceptions) { [[Errno::EROFS, 'Read-only file system @ rb_sysopen - /destination'], nil].each }
      let(:pre_assemble_results) { [nil, { pre_assem_finished: true, status: 'success' }].each }

      let(:yaml) { YAML.load_stream(File.read(batch.progress_log_file)) }

      before do
        allow_any_instance_of(PreAssembly::DigitalObject).to receive(:openable?).and_return(true)
        # simulate an exception occurring during pre-assembly of the first object
        allow(PreAssembly::DigitalObject).to receive(:new).and_wrap_original do |m, *args|
          m.call(*args).tap do |dobj|
            stage_files_exception = stage_files_exceptions.next
            pre_assemble_result = pre_assemble_results.next
            allow(dobj).to receive(:stage_files).and_raise(*stage_files_exception) if stage_files_exception
            allow(dobj).to receive(:pre_assemble).and_return(pre_assemble_result) if pre_assemble_result
          end
        end
        batch.send(:pre_assemble_objects)
      end

      it 'rescues the exception and proceeds, logs the error, indicates errors occurred, and sets the error message' do
        expect(batch.objects_had_errors).to be true
        expect(batch.error_message).to eq '1 objects had errors during pre-assembly'
        # first object logs an error
        expect(yaml[0]).to include(status: 'error', message: 'Read-only file system - Read-only file system @ rb_sysopen - /destination', pre_assem_finished: false)
        # second object is a success
        expect(yaml[1]).to include(status: 'success', pre_assem_finished: true)
      end
    end
  end

  describe '#pre_assembled_object_containers' do
    it 'returns expected hash of skippable items' do
      allow(multimedia).to receive(:progress_log_file).and_return('spec/fixtures/input/mock_progress_log.yaml')
      expect(multimedia.send(:pre_assembled_object_containers)).to eq('aa' => true, 'bb' => true)
    end
  end

  describe '#info_for_log' do
    it 'returns a string with the expected values' do
      info_for_log = flat_dir_images.send(:info_for_log)
      expect(info_for_log).to match(/content_structure="#{flat_dir_images.content_structure}"/)
      expect(info_for_log).to match(/project_name="#{flat_dir_images.project_name}"/)
      expect(info_for_log).to match(/staging_location="#{flat_dir_images.staging_location}"/)
      expect(info_for_log).to match(/assembly_staging_dir="#{Settings.assembly_staging_dir}"/)
      expect(info_for_log).to match(/environment="test"/)
    end
  end

  describe '#digital_objects' do
    context 'with flat folder structure' do
      let(:batch) { batch_setup(:folder_manifest) }

      it 'calculates size correctly' do
        # #size on the Enumerator object is calculated in a way that avoids iterating over the whole thing
        expect(flat_dir_images.digital_objects.size).to eq(flat_dir_images.digital_objects.to_a.size)
      end

      it 'finds the correct number of objects' do
        expect(batch.digital_objects.size).to eq(3)
      end

      it 'sets the correct relative_paths for the files' do
        expect(relative_file_paths).to eq [
          [
            'image1.tif',
            'image2.tif'
          ],
          [
            'image1.tif',
            'image2.tif'
          ],
          [
            'image1.tif',
            'image2.tif'
          ]
        ]
      end

      it 'handles containers correctly' do
        expect(multimedia.digital_objects.first.container.size).to be > multimedia.staging_location.size
      end

      it 'augments the digital objects with additional information' do
        expect(flat_dir_images.digital_objects.size).to eq(3)
        extra_info = flat_dir_images.digital_objects.map { |dobj| { label: dobj.label, source_id: dobj.source_id } }
        expect(extra_info).to eq [
          {
            label: 'Avus 1937',
            source_id: 'foo-1.0'
          },
          {
            label: 'Avus 1938',
            source_id: 'foo-2.1'
          },
          {
            label: 'Avus 1938, 1956',
            source_id: 'foo-2.2'
          }
        ]
      end
    end

    context 'with hierarchical file structure' do
      let(:batch) { batch_setup(:hierarchical_files) }

      it 'finds the correct number of objects' do
        expect(batch.digital_objects.size).to eq(1)
      end

      it 'sets the correct relative_paths for the files' do
        expect(relative_file_paths).to eq [
          [
            'config/settings/test.yml',
            'config/settings/test1.yml',
            'config/settings/test2.yml',
            'config/test.yml',
            'images/image.jpg',
            'images/subdir/image.jpg',
            'test1.txt'
          ]
        ]
      end
    end
  end

  describe '#un_pre_assembled_objects' do
    it 'returns all objects if there are no pre_assembled_object_containers' do
      expect(digital_objects_equivalent?(flat_dir_images.un_pre_assembled_objects.to_a, flat_dir_images.digital_objects.to_a)).to be true
    end

    it 'calculates size correctly' do
      # #size on the Enumerator object is calculated in a way that avoids iterating over the whole thing
      expect(flat_dir_images.un_pre_assembled_objects.size).to eq(flat_dir_images.un_pre_assembled_objects.to_a.size)
    end

    it 'returns a filtered list of digital objects' do
      allow(flat_dir_images).to receive(:pre_assembled_object_containers).and_return({ flat_dir_images.digital_objects.to_a.last.container => true })
      o2p = flat_dir_images.un_pre_assembled_objects.to_a
      expect(o2p.size).to eq(flat_dir_images.digital_objects.size - 1)
      expect(digital_objects_equivalent?(o2p, flat_dir_images.digital_objects.to_a[0..-2])).to be true
    end
  end

  ### Private methods

  describe '#containers_via_manifest' do
    it 'calculates size correctly' do
      # #size on the Enumerator object is calculated in a way that avoids iterating over the whole thing
      expect(flat_dir_images.send(:containers_via_manifest).size).to eq(flat_dir_images.send(:containers_via_manifest).to_a.size)
    end

    it 'returns expected information' do
      vals = %w[123.tif 456.tif 789.tif]
      allow(flat_dir_images).to receive(:object_manifest_rows).and_return(vals.map { |v| { object: v } })
      expect(flat_dir_images.send(:containers_via_manifest).to_a).to eq(vals.map { |v| flat_dir_images.staging_location_with_path v })
    end
  end

  describe '#discover_items_via_crawl' do
    it 'returns expected information' do
      # these are the actual files in the spec/fixtures/flat_dir_images staging directory
      items = %w[checksums.txt image1.tif image2.tif image3.tif manifest.csv manifest_badsourceid_column.csv].map { |i| flat_dir_images.staging_location_with_path i }
      expect(flat_dir_images.send(:discover_items_via_crawl, flat_dir_images.staging_location)).to eq(items.sort)
    end
  end

  describe '#load_checksums' do
    it 'loads checksums and attaches them to the ObjectFiles' do
      multimedia.digital_objects.each do |dobj|
        dobj.object_files.each { |f| expect(f.checksum).to be_nil }
        batch.send(:load_checksums, dobj)
        dobj.object_files.each { |f| expect(f.checksum).to match(md5_regex) }
      end
    end
  end

  describe 'file and directory utilities' do
    let(:relative) { 'abc/def.jpg' }
    let(:full) { flat_dir_images.staging_location_with_path(relative) }

    it '#staging_location_with_path returns expected value' do
      expect(flat_dir_images.staging_location_with_path(relative)).to eq('spec/fixtures/flat_dir_images/abc/def.jpg')
    end
  end
end
