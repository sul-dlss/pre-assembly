# frozen_string_literal: true

RSpec.describe ObjectFileValidator do
  subject(:validator) { described_class.new(object: object, bundle: bundle) }

  let(:bundle) { bundle_setup(:flat_dir_images) }

  describe '#validate' do
    subject(:json) { validator.validate.as_json }

    let(:object) { bundle.objects_to_process.first }

    before do
      allow(object).to receive(:pid).and_return('kk203bw3276')
      allow(validator).to receive(:registration_check).and_return({}) # pretend everything is in Dor
    end

    it 'converts a DigtialObject to structured data (Hash)' do
      expect(validator.validate.as_json).to match a_hash_including(
        counts: a_hash_including(total_size: 0),
        errors: a_hash_including(missing_files: true),
        druid: 'druid:kk203bw3276'
      )
    end

    context 'folders are empty' do
      it 'adds empty_object error' do
        expect(json).to match a_hash_including(errors: a_hash_including(empty_object: true))
      end
    end

    context 'folders are not empty' do
      let(:obj_file) { instance_double(PreAssembly::ObjectFile, path: 'random/path', filesize: 324, mimetype: '') }

      before do
        allow(object).to receive(:object_files).and_return([obj_file, obj_file])
        # allow(report).to receive(:using_media_manifest?).and_return(false)
        allow(validator).to receive(:registration_check).and_return({}) # pretend everything is in Dor
      end

      it 'does not add empty_object error' do
        expect(json).not_to include(a_hash_including(empty_object: true))
      end
    end

    context 'missing_media_container_name_or_manifest' do
      let(:bundle) { bundle_setup(:media_missing) }
      let(:obj_file) { instance_double(PreAssembly::ObjectFile, path: '', filesize: 324, mimetype: '') }

      before do
        allow(object).to receive(:object_files).and_return([obj_file, obj_file])
        # allow(report).to receive(:using_media_manifest?).and_return(true)
        allow(validator).to receive(:registration_check).and_return({}) # pretend everything is in Dor
      end

      it 'adds missing_media_container_name_or_manifest error' do
        expect(json).to match a_hash_including(errors: a_hash_including(missing_media_container_name_or_manifest: true))
      end
    end
  end
end