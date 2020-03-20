# frozen_string_literal: true

RSpec.describe PreAssembly::ContentMetadataCreator do
  subject(:creator) do
    described_class.new(druid_id: druid_id,
                        content_md_creation: content_md_creation,
                        object_files: object_files,
                        content_md_creation_style: content_md_creation_style,
                        media_manifest: media_manifest,
                        add_file_attributes: add_file_attributes)
  end

  let(:druid_id) { 'foo' }
  let(:content_md_creation) { 'bar' }
  let(:content_md_creation_style) { 'baz' }
  let(:add_file_attributes) { false }
  let(:media_manifest) { 'quix' }

  describe '#content_object_files' do
    let(:files) { %w[file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif] }
    let(:object_files) do
      files.map do |f|
        PreAssembly::ObjectFile.new("/path/to/#{f}", relative_path: f)
      end
    end

    it 'filters @object_files correctly' do
      m = files.size / 2

      # All of them are included in content.
      expect(creator.send(:content_object_files).size).to eq(files.size)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| object_files[i].exclude_from_content = true }
      ofiles = creator.send(:content_object_files)
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map(&:relative_path)).to eq(files[m..-1].sort)
    end
  end

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
                bundle: :bar, style: content_md_creation_style, add_file_attributes: false)
      end
    end

    context 'when add_file_attributes is true' do
      let(:add_file_attributes) { true }

      it 'passes add_file_attributes' do
        creator.create
        expect(Assembly::ContentMetadata).to have_received(:create_content_metadata)
          .with(druid: druid_id, objects: object_files, add_exif: false,
                bundle: :bar, style: content_md_creation_style, add_file_attributes: true)
      end
    end
  end
end
