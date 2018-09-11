RSpec.describe CsvImporter do
  describe '#parse_to_hash' do
    let(:manifest) do
      described_class.parse_to_hash("#{Rails.root}/spec/test_data/flat_dir_images/manifest.csv")
    end

    it "loads a CSV as a hash with indifferent access" do
      expect(manifest).to be_an(Array)
      expect(manifest.size).to eq(3)
      headers = %w{format sourceid filename label year inst_notes prod_notes has_more_metadata description}
      expect(manifest).to all(be_an(ActiveSupport::HashWithIndifferentAccess)) # accessible w/ string and symbols
      expect(manifest).to all(include(*headers))
      expect(manifest[0][:description]).to be_nil
      expect(manifest[1][:description]).to eq('')
      expect(manifest[2][:description]).to eq('yo, this is a description')
    end
  end
end
