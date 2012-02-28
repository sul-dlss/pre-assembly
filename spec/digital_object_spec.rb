require 'tmpdir'
require 'fileutils'

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


  describe "initialization and other setup" do

    it "can initialize a digital object" do
      @dobj.should be_kind_of Assembly::DigitalObject
    end

    it "can add images to the digital object" do
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

  describe "image staging" do
    
    it "should be able to stage images in both :move and :copy modes" do
      tests = {
        false => 'druid:ab123cd4567',
        true  => 'druid:xy111zz2222',
      }
      tests.each do |copy_to_staging, druid|

        bundle       = Assembly::Bundle.new :copy_to_staging => copy_to_staging
        stager       = bundle.get_stager
        @dobj.druid  = Druid.new druid
        @dobj.images = []

        Dir.mktmpdir do |tmp_area|
          # Add images to the digital object.
          (1..3).each do |i|
            f = "image_#{i}.tif"
            ps = {
              :file_name => f,
              :full_path => "#{tmp_area}/#{f}",
            }
            FileUtils.touch ps[:full_path]
            @dobj.add_image ps
          end

          # Stage the images.
          base_target_dir = "#{tmp_area}/target"
          FileUtils.mkdir base_target_dir
          @dobj.stage_images stager, base_target_dir

          # Check outcome.
          @dobj.images.each do |img|
            staged_img_path = File.join @dobj.druid_tree_dir, img.file_name
            File.exists?(img.full_path).should   == copy_to_staging
            File.exists?(staged_img_path).should == true
          end
        end
      end

    end

  end

end
