describe PreAssembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id => 'qq333xx4444',
      :source_id    => 'SourceIDFoo',
      :project_name => 'ProjectBar',
      :label        => 'LabelQuux',
    }
    @dobj          = PreAssembly::DigitalObject.new @ps
    @druid         = Druid.new 'druid:ab123cd4567'
    @druid_alt     = Druid.new 'druid:ee222vv4444'
    @publish_attr  = { :preserve => 'yes', :shelve => 'no', :publish => 'no' }
    @provider_attr = {:foo => '123', :bar => '456'}
    @tmp_dir_args  = [nil, 'tmp']
  end

  def add_images_to_dobj(img_dir = '/tmp')
    (1..2).each do |i|
      f = "image_#{i}.tif"
      @dobj.add_image(
        :file_name     => f,
        :full_path     => "#{img_dir}/#{f}",
        :provider_attr => {:i => i}.merge(@provider_attr),
        :exp_md5       => "#{i}" * 4
      )
    end
  end

  def noko_doc(x)
    Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
  end

  describe "initialization and other setup" do

    it "can initialize a digital object" do
      @dobj.should be_kind_of PreAssembly::DigitalObject
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
      rps[:label].should == "LabelQuux"
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

        bundle       = PreAssembly::Bundle.new :copy_to_staging => c2s
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
      @dobj.druid = @druid
      add_images_to_dobj
      @dobj.generate_content_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <contentMetadata objectId="ab123cd4567">
          <resource sequence="1" id="ab123cd4567_1">
            <label>Image 1</label>
            <file preserve="yes" publish="no" shelve="no" id="image_1.tif">
              <provider_checksum type="md5">1111</provider_checksum>
            </file>
          </resource>
          <resource sequence="2" id="ab123cd4567_2">
            <label>Image 2</label>
            <file preserve="yes" publish="no" shelve="no" id="image_2.tif">
              <provider_checksum type="md5">2222</provider_checksum>
            </file>
          </resource>
        </contentMetadata>
      END
      @exp_xml = noko_doc @exp_xml
    end
    
    it "should generate the expected xml text" do
      noko_doc(@dobj.content_metadata_xml).should be_equivalent_to @exp_xml
    end

    it "should be able to write the content_metadata XML to a file" do
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join tmp_area, @dobj.content_md_file_name

        File.exists?(file_name).should == false
        @dobj.write_content_metadata
        noko_doc(File.read file_name).should be_equivalent_to @exp_xml
      end
    end

  end

  describe "descriptive metadata" do

    before(:each) do
      @dobj.druid = @druid
      add_images_to_dobj
      @dobj.generate_desc_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd" version="3.3">
          <identifier file_name="image_1.tif">
            <note type="source note" ID="i">1</note>
            <note type="source note" ID="foo">123</note>
            <note type="source note" ID="bar">456</note>
          </identifier>
          <identifier file_name="image_2.tif">
            <note type="source note" ID="i">2</note>
            <note type="source note" ID="foo">123</note>
            <note type="source note" ID="bar">456</note>
          </identifier>
        </mods>
      END
      @exp_xml = noko_doc @exp_xml
    end
    
    it "should generate the expected xml text" do
      noko_doc(@dobj.desc_metadata_xml).should be_equivalent_to @exp_xml
    end

    it "should be able to write the desc_metadata XML to a file" do
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join tmp_area, @dobj.desc_md_file_name

        File.exists?(file_name).should == false
        @dobj.write_desc_metadata
        noko_doc(File.read file_name).should be_equivalent_to @exp_xml
      end
    end

  end

  describe "workflow metadata" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.generate_workflow_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <workflow objectId="druid:#{@druid.id}" id="assemblyWF">
          <process status="completed" name="start-assembly"/>
          <process status="waiting"   name="checksum"/>
          <process status="waiting"   name="checksum-compare"/>
        </workflow>
      END
      @exp_xml = noko_doc @exp_xml
    end
   
    it "should generate the expected xml text" do
      noko_doc(@dobj.workflow_metadata_xml).should be_equivalent_to @exp_xml
    end

    it "should be able to ......" do
      # TODO:
    end

  end

end
