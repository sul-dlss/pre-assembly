describe Assembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id => 'qq333xx4444',
      :source_id    => 'SourceIDFoo',
      :project_name => 'ProjectBar',
      :label        => 'LabelQuux',
    }
    @dobj          = Assembly::DigitalObject.new @ps
    @druid         = Druid.new 'druid:ab123cd4567'
    @druid_alt     = Druid.new 'druid:ee222vv4444'
    @publish_attr  = { :preserve => 'yes', :shelve => 'no', :publish => 'no' }
    @provider_attr = {:foo => 'FOO', :bar => 'BAR'}
    @tmp_dir_args  = [nil, 'tmp']
  end

  def add_images_to_dobj(img_dir = '/tmp')
    (1..2).each do |i|
      f = "image_#{i}.tif"
      @dobj.add_image(
        :file_name     => f,
        :full_path     => "#{img_dir}/#{f}",
        :provider_attr => @provider_attr
      )
    end
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
      d = @druid.druid
      @dobj.stub(:get_druid_from_suri).and_return(d)
      @dobj.pid.should == ''
      @dobj.druid.should == nil
      @dobj.claim_druid
      @dobj.pid.should == d
      @dobj.druid.should be_kind_of Druid
    end

    it "can generate registration parameters" do
      @dobj.druid = @druid
      rps = @dobj.registration_params
      rps.should             be_kind_of Hash
      rps[:source_id].should be_kind_of Hash
      rps[:tags].should      be_kind_of Array
      rps[:label].should == "ProjectBar_LabelQuux"
    end

    it "can generate registration parameters, even if label attribute is false" do
      @dobj.druid = @druid
      @dobj.label = nil
      ps = @dobj.registration_params
      ps[:label].should == "ProjectBar_#{@druid.id}"
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
      tests = { false => @druid, true  => @druid_alt }
      tests.each do |c2s, druid|

        bundle       = Assembly::Bundle.new :copy_to_staging => c2s
        stager       = bundle.get_stager
        @dobj.druid  = druid
        @dobj.images = []

        Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
          # Add images to the digital object and create the files.
          add_images_to_dobj tmp_area
          @dobj.images.each { |img| FileUtils.touch img.full_path }

          # Stage the images.
          base_target_dir = "#{tmp_area}/target"
          FileUtils.mkdir base_target_dir
          @dobj.stage_images stager, base_target_dir

          # Check outcome.
          @dobj.images.each do |img|
            staged_img_path = File.join @dobj.druid_tree_dir, img.file_name
            File.exists?(img.full_path).should   == c2s
            File.exists?(staged_img_path).should == true
          end
        end

      end

    end

  end

  describe "content metadata" do

    before(:each) do
      drid = @druid.id
      @dobj.druid = @druid
      add_images_to_dobj
      @exp_cm = { :contentMetadata => {
        :objectId => drid,
        :resource => (1 .. 2).map { |i|
          {
            :label         => "Image #{i}",
            :id            => "#{drid}_#{i}",
            :sequence      => "#{i}",
            :file          => {"id" => "image_#{i}.tif"}.merge(@publish_attr),
            :provider_attr => @provider_attr,
          }
        }
      }}
      @dobj.generate_content_metadata
    end
    
    it "should be able to generate content_metadata correctly as YAML" do
      y = YAML::load @dobj.content_metadata_yml
      y.should == @exp_cm
    end

    it "should be able to write the content_metadata YAML to a file" do
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join tmp_area, @dobj.content_md_file_name

        File.exists?(file_name).should == false
        @dobj.write_content_metadata
        YAML::load_file(file_name).should == @exp_cm
      end
    end

  end

end
