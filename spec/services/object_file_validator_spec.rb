# frozen_string_literal: true

RSpec.describe ObjectFileValidator do
  let(:batch) { batch_setup(:flat_dir_images) }
  let(:cocina_obj) { build(:dro).new(structural:) }
  let(:structural) { { contains: [] } }
  let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, find: cocina_obj) }
  let(:validator) { described_class.new(object:, batch:) }

  before do
    allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
  end

  describe '#validate' do
    subject(:json) { validator.validate.as_json }

    let(:object) { batch.un_pre_assembled_objects.first }

    it 'converts a DigtialObject to structured data (Hash)' do
      expect(validator.validate.as_json).to match a_hash_including(
        counts: a_hash_including(total_size: 0),
        errors: a_hash_including(missing_files: true),
        druid: 'druid:oo000oo0000'
      )
    end

    context 'folders are empty' do
      it 'adds empty_object error' do
        expect(json).to match a_hash_including(errors: a_hash_including(empty_object: true))
      end
    end

    context 'folders are not empty' do
      let(:obj_file) { instance_double(PreAssembly::ObjectFile, path: '', relative_path: 'random/path', filesize: 324, mimetype: '') }

      before do
        allow(object).to receive(:object_files).and_return([obj_file, obj_file])
        allow(validator).to receive(:registration_check).and_return({}) # pretend everything is in Dor
      end

      it 'does not add empty_object error' do
        expect(json).not_to include(a_hash_including(empty_object: true))
      end
    end

    context 'missing_media_container_name_or_manifest' do
      let(:batch) { batch_setup(:media_missing) }
      let(:obj_file) { instance_double(PreAssembly::ObjectFile, path: '', relative_path: '', filesize: 324, mimetype: '') }

      before do
        allow(object).to receive(:object_files).and_return([obj_file, obj_file])
        allow(validator).to receive(:registration_check).and_return({}) # pretend everything is in Dor
      end

      it 'adds missing_media_container_name_or_manifest error' do
        expect(json).to match a_hash_including(errors: a_hash_including(missing_media_container_name_or_manifest: true))
      end
    end

    context 'dor services client does not find item' do
      before do
        allow(dor_services_client_object).to receive(:find).and_raise(Dor::Services::Client::NotFoundResponse)
      end

      it 'adds item_not_registered error' do
        expect(json).to match a_hash_including(errors: a_hash_including(item_not_registered: true))
      end
    end

    context 'when all file manifest files found on disk or ignored' do
      let(:batch) { batch_setup(:book_file_manifest) }

      it 'does not report files_found_mismatch' do
        expect(json).to match a_hash_including(errors: {})
      end
    end

    context 'when all files on disk not in file manifest' do
      let(:batch) { batch_setup(:book_file_manifest_extra_file_on_disk) }

      it 'reports files_found_mismatch' do
        expect(json).to match a_hash_including(errors: a_hash_including(files_found_mismatch: true))
      end
    end

    context 'when all file manifest files not found on disk or cocina file' do
      let(:batch) { batch_setup(:book_file_manifest_extra_file) }

      it 'reports files_found_mismatch' do
        expect(json).to match a_hash_including(errors: a_hash_including(files_found_mismatch: true))
      end
    end

    context 'when all file manifest files found on disk or cocina file' do
      let(:batch) { batch_setup(:book_file_manifest_extra_file) }

      let(:structural) do
        { contains: [
          {
            type: 'https://cocina.sul.stanford.edu/models/resources/file',
            externalIdentifier: 'bc234fg5678_2',
            label: 'page 0', version: 1,
            structural: {
              contains: [
                { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/5', label: 'page 0',
                  filename: 'page_0000.jpg', version: 1,
                  hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                  access: { view: 'dark', download: 'none', controlledDigitalLending: false },
                  administrative: { publish: true, sdrPreserve: true, shelve: false } }
              ]
            }
          }
        ] }
      end

      it 'does not report files_found_mismatch' do
        expect(json).to match a_hash_including(errors: {})
      end
    end
  end
end
