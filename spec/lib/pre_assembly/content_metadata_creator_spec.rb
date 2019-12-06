RSpec.describe PreAssembly::ContentMetadataCreator do
  subject(:object) do
    described_class.new(druid_id: druid_id,
                        content_md_creation: content_md_creation,
                        object_files: object_files,
                        content_md_creation_style: object_files,
                        media_manifest: media_manifest)
  end

  let(:druid_id) { 'foo' }
  let(:content_md_creation) { 'bar' }
  let(:content_md_creation_style) { 'baz' }
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
      expect(object.send(:content_object_files).size).to eq(files.size)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| object_files[i].exclude_from_content = true }
      ofiles = object.send(:content_object_files)
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map(&:relative_path)).to eq(files[m..-1].sort)
    end
  end
end
