# frozen_string_literal: true

RSpec.describe PreAssembly::ContentMetadataCreator do
  subject(:creator) do
    described_class.new(druid_id: druid_id,
                        object: druid_id,
                        content_md_creation: content_md_creation,
                        object_files: object_files,
                        content_md_creation_style: content_md_creation_style,
                        file_manifest: file_manifest,
                        reading_order: reading_order,
                        using_file_manifest: false,
                        add_file_attributes: add_file_attributes)
  end

  let(:druid_id) { 'foo' }
  let(:content_md_creation) { 'bar' }
  let(:content_md_creation_style) { 'baz' }
  let(:add_file_attributes) { false }
  let(:reading_order) { 'ltr' }
  let(:file_manifest) { 'quix' }

  describe '#create' do
    let(:files) { %w[file5.tif] }
    let(:object_files) do
      files.map do |f|
        PreAssembly::ObjectFile.new("/path/to/#{f}", relative_path: f)
      end
    end

    before do
      allow(Assembly::ContentMetadata).to receive(:create_content_metadata)
    end

    context 'when add_file_attributes is false' do
      it 'passes add_file_attributes' do
        creator.create
        expect(Assembly::ContentMetadata).to have_received(:create_content_metadata)
          .with(druid: druid_id, objects: object_files, add_exif: false,
                bundle: :bar, style: content_md_creation_style, reading_order: reading_order, add_file_attributes: false)
      end
    end

    context 'when add_file_attributes is true' do
      let(:add_file_attributes) { true }

      it 'passes add_file_attributes' do
        creator.create
        expect(Assembly::ContentMetadata).to have_received(:create_content_metadata)
          .with(druid: druid_id, objects: object_files, add_exif: false,
                bundle: :bar, style: content_md_creation_style, reading_order: reading_order, add_file_attributes: true)
      end
    end
  end
end
