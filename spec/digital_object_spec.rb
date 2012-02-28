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


  describe "registration" do

    it "can claim a druid" do
      d = 'druid:ab123cd4567'
      @dobj.stub(:get_druid_from_suri).and_return(d)
      @dobj.pid.should == ''
      @dobj.druid.should == nil
      @dobj.claim_druid
      @dobj.pid.should == d
      @dobj.druid.should be_kind_of Druid
    end

  end

end
