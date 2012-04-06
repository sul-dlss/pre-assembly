describe PreAssembly::DigitalObject do

  before(:each) do
    desc_metadata_xml_template=<<-END
      <?xml version="1.0"?>
      <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
        <typeOfResource>still image</typeOfResource>
        <genre authority="att">digital image</genre>
        <subject authority="lcsh">
          <topic>Automobile</topic>
          <topic>History</topic>
        </subject>
        <relatedItem type="host">
          <titleInfo>
            <title>The Collier Collection of the Revs Institute for Automotive Research</title>
          </titleInfo>
          <typeOfResource collection="yes"/>
        </relatedItem>
        <relatedItem type="original">
          <physicalDescription>
            <form authority="att">[[format]]</form>
          </physicalDescription>
        </relatedItem>
        <originInfo>
          <dateCreated>[[year]]</dateCreated>
        </originInfo>
        <titleInfo>
          <title>'[[label]]' is the label!</title>
        </titleInfo>
        <note>[[description]]</note>
        <note>ERB Test: <%=manifest_row['description']%></note>
        <identifier type="local" displayLabel="Revs ID">[[sourceid]]</identifier>
        <note type="source note" ID="foo">[[foo]]</note>
        <note type="source note" ID="bar">[[bar]]</note>        
      </mods>
      END

    @ps = {
      :apo_druid_id => 'qq333xx4444',
      :set_druid_id => 'mm111nn2222',
      :source_id    => 'SourceIDFoo',
      :desc_metadata_xml_template =>desc_metadata_xml_template,
      :project_name => 'ProjectBar',
      :label        => 'LabelQuux',
      :publish      => 'no',
      :shelve       => 'no',
      :preserve     => 'yes'      
    }
    @dobj          = PreAssembly::DigitalObject.new @ps
    @druid         = Druid.new 'druid:ab123cd4567'
    @druid_alt     = Druid.new 'druid:ee222vv4444'
    @provider_attr = {'sourceid'=>'foo-1','label'=>'this is a label','year'=>'2012','description'=>'this is a description','format'=>'film','foo' => '123', 'bar' => '456'}
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

    it "can generate add_relationship parameters" do
      @dobj.druid = @druid
      exp = [:is_member_of, "info:fedora/druid:mm111nn2222"] 
      arps = @dobj.add_relationship_params.should == exp
    end

    it "can exercise register()" do
      @dobj.dor_object.should == nil
      @dobj.stub(:register_in_dor).and_return(1234)
      @dobj.register
      @dobj.dor_object.should == 1234
    end

    it "can exercise unregister(), with external calls stubbed" do
      @dobj.dor_object = 1234
      @dobj.stub :delete_from_dor
      @dobj.stub :set_workflow_step_to_error
      @dobj.unregister
      @dobj.dor_object.should == nil
    end

  end

  describe "image staging" do
    
    it "should be able to copy images successfully" do
        bundle       = PreAssembly::Bundle.new :project_style => :style_revs
        @dobj.druid  = @druid
        @dobj.images = []

        Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
          # Add images to the digital object and create the files.
          add_images_to_dobj tmp_area
          @dobj.images.each { |img| FileUtils.touch img.full_path }

          # Stage the images.
          base_target_dir = "#{tmp_area}/target"
          FileUtils.mkdir base_target_dir
          @dobj.stage_images bundle.stager, base_target_dir

          # Check outcome.
          @dobj.images.each do |img|
            staged_img_path = File.join @dobj.druid_tree_dir, img.file_name
            # Both source and copy should exist.
            File.exists?(img.full_path).should   == true
            File.exists?(staged_img_path).should == true
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
        <?xml version="1.0"?>
        <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
          <typeOfResource>still image</typeOfResource>
          <genre authority="att">digital image</genre>
          <subject authority="lcsh">
            <topic>Automobile</topic>
            <topic>History</topic>
          </subject>
          <relatedItem type="host">
            <titleInfo>
              <title>The Collier Collection of the Revs Institute for Automotive Research</title>
            </titleInfo>
            <typeOfResource collection="yes"/>
          </relatedItem>
          <relatedItem type="original">
            <physicalDescription>
              <form authority="att">film</form>
            </physicalDescription>
          </relatedItem>
          <originInfo>
            <dateCreated>2012</dateCreated>
          </originInfo>
          <titleInfo>
            <title>'this is a label' is the label!</title>
          </titleInfo>
          <note>this is a description</note>
          <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
          <note>ERB Test: this is a description</note>          
          <note type="source note" ID="foo">123</note>
          <note type="source note" ID="bar">456</note>
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
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <workflow objectId="druid:#{@druid.id}" id="assemblyWF">
          <process status="completed" name="start-assembly"/>
          <process status="waiting"   name="jp2-create"/>
          <process status="waiting"   name="checksum-compute"/>
          <process status="waiting"   name="checksum-compare"/>
          <process status="waiting"   name="exif-collect"/>
          <process status="waiting"   name="accessioning-initiate"/>
        </workflow>
      END
      @exp_xml = noko_doc @exp_xml
    end
   
    it "should generate the expected xml text" do
      @dobj.generate_workflow_metadata
      noko_doc(@dobj.workflow_metadata_xml).should be_equivalent_to @exp_xml
    end

    it "should be able to exercise initialize_assembly_workflow()" do
      @dobj.should_receive(:create_workflow_in_dor).once
      @dobj.initialize_assembly_workflow
    end

  end

end
