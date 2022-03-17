# frozen_string_literal: true

RSpec.describe CsvImporter do
  describe '#parse_to_hash' do
    let(:manifest) do
      described_class.parse_to_hash(Rails.root.join('spec/test_data/flat_dir_images/manifest.csv'))
    end

    it 'loads a CSV as a hash with indifferent access' do
      expect(manifest).to be_an(Array)
      expect(manifest.size).to eq(3)
      headers = %w[format sourceid object label year inst_notes prod_notes has_more_metadata description]
      expect(manifest).to all(be_an(ActiveSupport::HashWithIndifferentAccess)) # accessible w/ string and symbols
      expect(manifest).to all(include(*headers))
      expect(manifest.pluck(:description)).to eq([nil, '', 'yo, this is a description'])
    end

    context 'windows manifest.csv' do
      let(:manifest) do
        described_class.parse_to_hash(Rails.root.join('spec/test_data/windows_manifest/manifest.csv'))
      end

      it 'loads a CSV as a hash and provides values' do
        expect(manifest.size).to eq(7)
        expect(manifest).to be_an(Array)
        headers = %w[object druid]
        expect(manifest).to all(be_an(ActiveSupport::HashWithIndifferentAccess)) # accessible w/ string and symbols
        expect(manifest).to all(include(*headers))
      end
    end
  end
end
