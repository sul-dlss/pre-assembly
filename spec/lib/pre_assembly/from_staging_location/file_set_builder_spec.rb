# frozen_string_literal: true

RSpec.describe PreAssembly::FromStagingLocation::FileSetBuilder do
  describe '.build' do
    let(:base_path) { 'spec/fixtures/geo/gn330dv6119' }
    let(:objects) do
      [
        Assembly::ObjectFile.new("#{base_path}/data.zip", relative_path: 'data.zip'),
        Assembly::ObjectFile.new("#{base_path}/preview.jpg", relative_path: 'preview.jpg')
      ]
    end

    it 'puts all files in a single FileSet for the single processing configuration' do
      filesets = described_class.build(processing_configuration: :single, objects:, style: :geo, ocr_available: false)

      expect(filesets.size).to eq 1
      expect(filesets.first.files.map(&:relative_path)).to eq ['data.zip', 'preview.jpg']
    end
  end
end
