describe Assembly::DigitalObject do

  before(:each) do
    @ps = {
    }
    @dobj = Assembly::DigitalObject.new @ps
  end


  describe "initialize() and other setup" do

    it "can initialize a DigitalObject" do
      @dobj.should be_kind_of Assembly::DigitalObject
    end

    it "can add images" do
      n = 4
      (1..n).each { |i| @dobj.add_image "#{i}.tif" }
      @dobj.images.should have(n).items
    end

  end


end
