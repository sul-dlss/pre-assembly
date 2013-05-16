describe PreAssembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id  => 'druid:qq333xx4444',
      :set_druid_id  => 'druid:mm111nn2222',
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      :publish_attr  => { :publish => 'no', :shelve => 'no', :preserve => 'yes' },
      :project_style => {},
      :content_md_creation => {},
      :bundle_dir    => 'spec/test_data/bundle_input_g',
      :new_druid_tree_format => true,
      :staging_style=>'copy'
    }
    @dobj         = PreAssembly::DigitalObject.new @ps
    
    @dru          = 'gn330dv6119'
    @pid          = "druid:#{@dru}"
    @druid        = DruidTools::Druid.new @pid
    @tmp_dir_args = [nil, 'tmp']
    @dobj.object_files = []
  end

  def add_object_files(extension='tif')
    (1..2).each do |i|
      f = "image#{i}.#{extension}"
      @dobj.object_files.push PreAssembly::ObjectFile.new(
        :path                 => "#{@dobj.bundle_dir}/#{@dru}/#{f}",
        :relative_path        => f,
        :exclude_from_content => false,
        :checksum             => "#{i}" * 4
      )
    end
  end


  ####################

  describe "initialization and other setup" do

    it "can initialize a digital object" do
      @dobj.should be_kind_of PreAssembly::DigitalObject
    end

  end

  ####################

  describe "determining druid: get_pid_from_container_barcode()" do

    before(:each) do
      @druids = %w(druid:aa00aaa0000 druid:cc11bbb1111 druid:dd22eee2222)
      apos = %w(druid:aa00aaa9999 druid:bb00bbb9999 druid:cc00ccc9999)
      apos = apos.map { |a| double('apo', :pid => a) }
      @barcode = '36105115575834'
      @dobj.stub(:container_basename).and_return @barcode
      @dobj.stub(:query_dor_by_barcode).and_return @druids
      @dobj.stub(:get_dor_item_apos).and_return apos
      @stubbed_return_vals = @druids.map { false }
    end

    it "should return DruidMinter.next if get_druid_from=druid_minter" do
      exp = PreAssembly::DruidMinter.current
      @dobj.project_style[:get_druid_from] = :druid_minter
      @dobj.should_not_receive :container_basename
      @dobj.get_pid_from_druid_minter.should == exp.next
    end

    it "should return nil whether there are no matches" do
      @dobj.stub(:apo_matches_exactly_one?).and_return *@stubbed_return_vals
      @dobj.get_pid_from_container_barcode.should == nil
    end

    it "should return the druid of the object with the matching APO" do
      @druids.each_with_index do |druid, i|
        @stubbed_return_vals[i] = true
        @dobj.stub(:apo_matches_exactly_one?).and_return *@stubbed_return_vals
        @dobj.get_pid_from_container_barcode.should == @druids[i]
        @stubbed_return_vals[i] = false
      end
    end

  end

  ####################

  describe "determining the druid: other" do

    it "determine_druid() should set correct values for @pid and @druid" do
      # Setup.
      dru = 'aa111bb2222'
      @dobj.project_style[:get_druid_from] = :container
      @dobj.container     = "foo/bar/#{dru}"
      # Before and after assertions.
      @dobj.pid.should   == ''
      @dobj.druid.should == nil
      @dobj.determine_druid
      @dobj.pid.should   == "druid:#{dru}"
      @dobj.druid.should be_kind_of DruidTools::Druid
    end

    it "get_pid_from_container() extracts druid from basename of object container" do
      d = 'xx111yy2222'
      @dobj.container = "foo/bar/#{d}"
      @dobj.get_pid_from_container.should == "druid:#{d}"
    end

    it "container_basename() should work" do
      d = 'xx111yy2222'
      @dobj.container = "foo/bar/#{d}"
      @dobj.container_basename.should == d
    end

    it "apo_matches_exactly_one?() should work" do
      z = 'zz00zzz0000'
      apos = %w(foo bar fubb)
      @dobj.apo_druid_id = z
      @dobj.apo_matches_exactly_one?(apos).should == false  # Too few.
      apos.push z
      @dobj.apo_matches_exactly_one?(apos).should == true   # One = just right.
      apos.push z
      @dobj.apo_matches_exactly_one?(apos).should == false  # Too many.
    end

  end

  ####################

  describe "register()" do

    it "should do nothing if should_register is false" do
      @dobj.project_style[:should_register] = false
      @dobj.should_not_receive :register_in_dor
      @dobj.register
    end

    it "can exercise method using stubbed exernal calls" do
      @dobj.project_style[:should_register] = true
      @dobj.stub(:register_in_dor).and_return(1234)
      @dobj.dor_object.should == nil
      @dobj.register
      @dobj.dor_object.should == 1234
    end

    it "can exercise registration_params() an get expected data structure" do
      @dobj.druid = @druid
      @dobj.label = "LabelQuux"
      rps = @dobj.registration_params
      rps.should             be_kind_of Hash
      rps[:source_id].should be_kind_of Hash
      rps[:tags].should      be_kind_of Array
      rps[:label].should == "LabelQuux"
    end

  end

  ####################

  describe "add_dor_object_to_set()" do

    it "should do nothing when @set_druid_id is false" do
      fake = double('dor_object', :add_relationship => 11, :save => 22)
      @dobj.dor_object = fake
      @dobj.set_druid_id = nil
      fake.should_not_receive :add_relationship
      @dobj.add_dor_object_to_set
    end

    it "can exercise method using stubbed exernal calls" do
      @dobj.dor_object = double('dor_object', :add_relationship => nil, :save => nil)
      @dobj.add_dor_object_to_set
    end

    it "add_relationship() returns expected data structure" do
      @dobj.druid = @druid
      exp1 = [:is_member_of, "info:fedora/druid:mm111nn2222"]
      exp2 = [:is_member_of_collection, "info:fedora/druid:mm111nn2222"]
      arps = @dobj.add_member_relationship_params.should == exp1
      arps = @dobj.add_collection_relationship_params.should == exp2
    end

  end

  ####################

  describe "unregister()" do

    before(:each) do
      @dobj.dor_object = 1234
      Assembly::Utils.stub :delete_from_dor
      Assembly::Utils.stub :set_workflow_step_to_error
    end

    it "should do nothing unless the digitial object was registered by pre-assembly" do
      @dobj.should_not_receive :delete_from_dor
      @dobj.reg_by_pre_assembly = false
      @dobj.unregister
    end

    it "can exercise unregister(), with external calls stubbed" do
      @dobj.reg_by_pre_assembly = true
      @dobj.unregister
      @dobj.dor_object.should == nil
      @dobj.reg_by_pre_assembly.should == false
    end

  end


  ####################

  describe "file staging" do

    it "should be able to copy stageable items successfully" do
      @dobj.druid = @druid

      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        # Add some stageable items to the digital object, and create those files.
        files                 = [1,2,3].map { |n| "image#{n}.tif" }
        @dobj.bundle_dir      = tmp_area
        @dobj.staging_dir     = "#{tmp_area}/target"
        @dobj.stageable_items = files.map { |f| File.expand_path("#{tmp_area}/#{f}") }
        @dobj.stageable_items.each { |si| FileUtils.touch si }
        @dobj.staging_style='copy'
        
        # Stage the files via copy.
        FileUtils.mkdir @dobj.staging_dir
        @dobj.stage_files

        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = @dobj.stageable_items[i]
          cpy = File.join @dobj.content_dir, f
          File.exists?(src).should == true
          File.exists?(cpy).should == true
        end
      end
    end
    
    it "should be able to symlink stageable items successfully" do
      @dobj.druid = @druid
      
       Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        #Add some stageable items to the digital object, and create those files.
        files                 = [1,2,3].map { |n| "image#{n}.tif" }
        @dobj.bundle_dir      = tmp_area
        @dobj.staging_dir     = "#{tmp_area}/target"
        @dobj.stageable_items = files.map { |f| File.expand_path("#{tmp_area}/#{f}") }
        @dobj.stageable_items.each { |si| FileUtils.touch si }
        @dobj.staging_style='symlink'

        # Stage the files via symlink.
        FileUtils.mkdir @dobj.staging_dir
        @dobj.stage_files

        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = @dobj.stageable_items[i]
          cpy = File.join @dobj.content_dir, f
          File.exists?(src).should == true
          File.exists?(cpy).should == true
          File.symlink?(cpy).should == true
        end
     end
    end

  end

  ####################

  describe "default content metadata" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='default'
      @dobj.project_style[:content_structure]='simple_image'
      add_object_files('tif')
      add_object_files('jp2')      
      @dobj.create_content_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <contentMetadata type="image" objectId="gn330dv6119">
          <resource type="image" id="gn330dv6119_1" sequence="1">
            <label>Image 1</label>
            <file publish="yes" shelve="yes" id="image1.jp2" preserve="no">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_2" sequence="2">
            <label>Image 2</label>
            <file publish="no" shelve="no" id="image1.tif" preserve="yes">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_3" sequence="3">
            <label>Image 3</label>
            <file publish="yes" shelve="yes" id="image2.jp2" preserve="no">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_4" sequence="4">
            <label>Image 4</label>
            <file publish="no" shelve="no" id="image2.tif" preserve="yes">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
        </contentMetadata>          
      END
      @exp_xml = noko_doc @exp_xml
    end

    it "content_object_files() should filter @object_files correctly" do
      # Generate some object_files.
      files = %w(file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif)
      n = files.size
      m = n / 2
      @dobj.object_files = files.map do |f|
        PreAssembly::ObjectFile.new(:exclude_from_content => false, :relative_path => f)
      end
      # All of them are included in content.
      @dobj.content_object_files.size.should == n
      # Now exclude some. Make sure we got correct N of items.
      (0 ... m).each { |i| @dobj.object_files[i].exclude_from_content = true }
      ofiles = @dobj.content_object_files
      ofiles.size.should == m
      # Also check their ordering.
      ofiles.map { |f| f.relative_path }.should == files[m .. -1].sort
    end

    it "should generate the expected xml text" do
      noko_doc(@dobj.content_md_xml).should be_equivalent_to @exp_xml
    end

    it "should be able to write the content_metadata XML to a file" do
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join(tmp_area,"metadata",@dobj.content_md_file)

        File.exists?(file_name).should == false
        @dobj.write_content_metadata
        noko_doc(File.read file_name).should be_equivalent_to @exp_xml
      end
    end

  end

  #########
  describe "check the druid tree directories and content and metadata locations using both the new style and the old style" do

    it "should have the correct druid tree folders using the new style" do
      @dobj.druid = @druid
      @dobj.new_druid_tree_format = true
      @dobj.druid_tree_dir.should == 'gn/330/dv/6119/gn330dv6119'
      @dobj.metadata_dir.should == 'gn/330/dv/6119/gn330dv6119/metadata'
      @dobj.content_dir.should == 'gn/330/dv/6119/gn330dv6119/content'
    end

    it "should have the correct druid tree folders using the old style" do
      @dobj.druid = @druid
      @dobj.new_druid_tree_format = false
      @dobj.druid_tree_dir.should == 'gn/330/dv/6119'
      @dobj.metadata_dir.should == 'gn/330/dv/6119'
      @dobj.content_dir.should == 'gn/330/dv/6119'
    end

  end

  ####################

  describe "no content metadata generated" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='none'
      @dobj.project_style[:content_structure]='simple_book'
      @dobj.publish_attr=nil      
      add_object_files('tif')
      add_object_files('jp2')
      @dobj.create_content_metadata
    end

    it "should not generate any xml text" do
      @dobj.content_md_xml.should == ""
    end

  end
  
  ####################
  
  ####################

  describe "bundled by filename, simple book content metadata without file attributes" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='filename'
      @dobj.project_style[:content_structure]='simple_book'
      @dobj.publish_attr=nil      
      add_object_files('tif')
      add_object_files('jp2')
      @dobj.create_content_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
      <contentMetadata type="book" objectId="gn330dv6119">
        <resource type="page" sequence="1" id="gn330dv6119_1">
          <label>Page 1</label>
          <file id="image1.jp2">
            <checksum type="md5">1111</checksum>
          </file>
          <file id="image1.tif">
            <checksum type="md5">1111</checksum>
          </file>
        </resource>
        <resource type="page" sequence="2" id="gn330dv6119_2">
          <label>Page 2</label>
          <file id="image2.jp2">
            <checksum type="md5">2222</checksum>
          </file>
          <file id="image2.tif">
            <checksum type="md5">2222</checksum>
          </file>
        </resource>
      </contentMetadata>
      END
      @exp_xml = noko_doc @exp_xml
    end

    it "should generate the expected xml text" do
      noko_doc(@dobj.content_md_xml).should be_equivalent_to @exp_xml
    end

  end
  
  ####################


  describe "content metadata generated from object tag in DOR if present" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='default'
      @dobj.project_style[:content_structure]='simple_image' # this is the default
      @dobj.stub!(:content_type_tag).and_return('File')       # this is what the object tag says, so we should get the file type out
      @dobj.project_style[:should_register]=false
      add_object_files('tif')
      add_object_files('jp2')      
      @dobj.create_content_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <contentMetadata type="file" objectId="gn330dv6119">
          <resource type="file" id="gn330dv6119_1" sequence="1">
            <label>File 1</label>
            <file publish="yes" shelve="yes" id="image1.jp2" preserve="no">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="file" id="gn330dv6119_2" sequence="2">
            <label>File 2</label>
            <file publish="no" shelve="no" id="image1.tif" preserve="yes">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="file" id="gn330dv6119_3" sequence="3">
            <label>File 3</label>
            <file publish="yes" shelve="yes" id="image2.jp2" preserve="no">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="file" id="gn330dv6119_4" sequence="4">
            <label>File 4</label>
            <file publish="no" shelve="no" id="image2.tif" preserve="yes">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
        </contentMetadata>          
      END
      @exp_xml = noko_doc @exp_xml
    end

    it "content_object_files() should filter @object_files correctly" do
      # Generate some object_files.
      files = %w(file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif)
      n = files.size
      m = n / 2
      @dobj.object_files = files.map do |f|
        PreAssembly::ObjectFile.new(:exclude_from_content => false, :relative_path => f)
      end
      # All of them are included in content.
      @dobj.content_object_files.size.should == n
      # Now exclude some. Make sure we got correct N of items.
      (0 ... m).each { |i| @dobj.object_files[i].exclude_from_content = true }
      ofiles = @dobj.content_object_files
      ofiles.size.should == m
      # Also check their ordering.
      ofiles.map { |f| f.relative_path }.should == files[m .. -1].sort
    end

    it "should generate the expected xml text" do
      noko_doc(@dobj.content_md_xml).should be_equivalent_to @exp_xml
    end
  end

  ####################
  
  describe "descriptive metadata" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.manifest_row = {
        :sourceid    => 'foo-1',
        :label       => 'this is < a label with an & that will break XML unless it is escaped',
        :year        => '2012',
        :description => 'this is a description > another description < other stuff',
        :format      => 'film',
        :foo         =>  '123',
        :bar         =>  '456',
      }
      @dobj.desc_md_template_xml = <<-END.gsub(/^ {8}/, '')
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
          <note>ERB Test: <%=manifest_row[:description]%></note>
          <identifier type="local" displayLabel="Revs ID">[[sourceid]]</identifier>
          <note type="source note" ID="foo">[[foo]]</note>
          <note type="source note" ID="bar">[[bar]]</note>
        </mods>
      END
      @exp_xml = <<-END.gsub(/^ {8}/, '')
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
            <title>'this is &lt; a label with an &amp; that will break XML unless it is escaped' is the label!</title>
          </titleInfo>
          <note>this is a description &gt; another description &lt; other stuff</note>
          <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
          <note>ERB Test: this is a description &gt; another description &lt; other stuff</note>
          <note type="source note" ID="foo">123</note>
          <note type="source note" ID="bar">456</note>
        </mods>
      END
      @exp_xml = noko_doc @exp_xml
    end

    it "generate_desc_metadata() should do nothing if there is no template" do
      @dobj.desc_md_template_xml = nil
      @dobj.should_not_receive :create_desc_metadata_xml
      @dobj.generate_desc_metadata
    end

    it "create_desc_metadata_xml() should generate the expected xml text" do
      @dobj.create_desc_metadata_xml
      noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
    end

    it "should be able to write the desc_metadata XML to a file" do
      @dobj.create_desc_metadata_xml
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join(tmp_area, "metadata",@dobj.desc_md_file)
        File.exists?(file_name).should == false
        @dobj.write_desc_metadata
        noko_doc(File.read file_name).should be_equivalent_to @exp_xml
      end
    end

  end

  ####################

  describe "initiate assembly workflow" do

    it "initialize_assembly_workflow() should do nothing if init_assembly_wf is false" do
      @dobj.init_assembly_wf = false
      @dobj.should_not_receive :assembly_workflow_url
      @dobj.initialize_assembly_workflow
    end

    it "assembly_workflow_url() should return expected value" do
      @dobj.pid = @pid
      url = @dobj.assembly_workflow_url
      url.should =~ /^http.+assemblyWF$/
      url.include?(@pid).should == true
    end

    it "assembly_workflow_url() should add the druid: prefix to the pid if it is missing, like it might be in the manifest" do
      @dobj.pid = @pid.gsub('druid:','')
      url = @dobj.assembly_workflow_url
      url.should =~ /^http.+assemblyWF$/
      url.include?(@pid).should == true
    end

  end

end
