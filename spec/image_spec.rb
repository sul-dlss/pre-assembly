describe PreAssembly::Image do

  before( :each ) do
    @ai = PreAssembly::Image.new(
      :file_name     => 'image1.tif',
      :full_path     => 'spec/test_data/bundle_input_a/image1.tif',
      :provider_attr => {},
      :exp_md5       => '4e3cd24dd79f3ec91622d9f8e5ab5afa'
    )
  end

  describe "initialization" do

    it "can initialize an Image" do
      @ai.should be_kind_of PreAssembly::Image
    end

  end

  describe "valid?()" do

    it "should return true with a valid tif" do
      @ai.valid?.should == true
    end

    it "should return false with an invalid tif" do
      @ai.full_path =  'spec/test_data/bundle_input_a/manifest.csv'
      @ai.valid?.should == false
    end

  end

end
