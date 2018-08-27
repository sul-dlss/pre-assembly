describe PreAssembly::ObjectFile do
  before do
    @f = described_class.new(
      :path => 'spec/test_data/bundle_input_a/image1.tif'
    )
  end

  describe "initialization" do
    it "can initialize an ObjectFile" do
      expect(@f).to be_kind_of described_class
    end
  end
end
