# frozen_string_literal: true

RSpec.describe PreAssembly::ObjectFile do
  let(:object_file) { described_class.new('spec/test_data/flat_dir_images/image1.tif') }

  describe 'initialization' do
    it 'can initialize an ObjectFile' do
      expect(object_file).to be_a(described_class) # useless test ("Does Ruby Work??")
    end
  end
end
