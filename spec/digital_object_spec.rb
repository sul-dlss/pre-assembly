describe Assembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id => 'aa123aa1234',
      :source_id    => 'SourceIDFoo',
      :project_name => 'ProjectBar',
      :label        => 'LabelQuux',
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

    it "can generate registration parameters" do
      @dobj.druid = Druid.new 'druid:ab123cd4567'
      rps = @dobj.registration_params
      rps.should             be_kind_of Hash
      rps[:source_id].should be_kind_of Hash
      rps[:tags].should      be_kind_of Array
      rps[:label].should == "ProjectBar_LabelQuux"
    end

    it "can generate registration parameters, even if label attribute is false" do
      @dobj.druid = Druid.new 'druid:ab123cd4567'
      @dobj.label = nil
      ps = @dobj.registration_params
      ps[:label].should == "ProjectBar_ab123cd4567"
    end

    it "can exercise register()" do
      @dobj.registration_info.should == nil
      @dobj.stub(:register_in_dor).and_return(1234)
      @dobj.register
      @dobj.registration_info.should == 1234
    end

    it "can exercise unregister()" do
      @dobj.registration_info = 1234
      @dobj.stub(:delete_from_dor)
      @dobj.unregister
      @dobj.registration_info.should == nil
    end

  end

end
