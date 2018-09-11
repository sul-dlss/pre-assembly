RSpec.describe PreAssembly::ObjectFile do
  before do
    @f = described_class.new(
      :path => 'spec/test_data/flat_dir_images/image1.tif'
    )
  end

  describe "initialization" do
    it "can initialize an ObjectFile" do
      expect(@f).to be_kind_of described_class
    end
  end
end
