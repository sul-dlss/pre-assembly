require 'spec_helper'

describe PreAssembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id  => 'druid:qq333xx4444',
      :set_druid_id  => 'druid:mm111nn2222',
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      :publish_attr  => { 'default' => {:publish => 'yes', :shelve => 'yes', :preserve => 'yes' }},
      :project_style => {:should_register=>true},
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
      expect(@dobj).to be_kind_of PreAssembly::DigitalObject
    end

  end

  ####################

  describe "determining druid: get_pid_from_container_barcode()" do

    before(:each) do
      @druids = %w(druid:aa00aaa0000 druid:cc11bbb1111 druid:dd22eee2222)
      apos = %w(druid:aa00aaa9999 druid:bb00bbb9999 druid:cc00ccc9999)
      apos = apos.map { |a| double('apo', :pid => a) }
      @barcode = '36105115575834'
      allow(@dobj).to receive(:container_basename).and_return @barcode
      allow(@dobj).to receive(:query_dor_by_barcode).and_return @druids
      allow(@dobj).to receive(:get_dor_item_apos).and_return apos
      @stubbed_return_vals = @druids.map { false }
    end

    it "should return DruidMinter.next if get_druid_from=druid_minter" do
      exp = PreAssembly::DruidMinter.current
      @dobj.project_style[:get_druid_from] = :druid_minter
      expect(@dobj).not_to receive :container_basename
      expect(@dobj.get_pid_from_druid_minter).to eq(exp.next)
    end

    it "should return nil whether there are no matches" do
      allow(@dobj).to receive(:apo_matches_exactly_one?).and_return *@stubbed_return_vals
      expect(@dobj.get_pid_from_container_barcode).to eq(nil)
    end

    it "should return the druid of the object with the matching APO" do
      @druids.each_with_index do |druid, i|
        @stubbed_return_vals[i] = true
        allow(@dobj).to receive(:apo_matches_exactly_one?).and_return *@stubbed_return_vals
        expect(@dobj.get_pid_from_container_barcode).to eq(@druids[i])
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
      expect(@dobj.pid).to   eq('')
      expect(@dobj.druid).to eq(nil)
      @dobj.determine_druid
      expect(@dobj.pid).to   eq("druid:#{dru}")
      expect(@dobj.druid).to be_kind_of DruidTools::Druid
    end

    it "get_pid_from_container() extracts druid from basename of object container" do
      d = 'xx111yy2222'
      @dobj.container = "foo/bar/#{d}"
      expect(@dobj.get_pid_from_container).to eq("druid:#{d}")
    end

    it "container_basename() should work" do
      d = 'xx111yy2222'
      @dobj.container = "foo/bar/#{d}"
      expect(@dobj.container_basename).to eq(d)
    end

    it "apo_matches_exactly_one?() should work" do
      z = 'zz00zzz0000'
      apos = %w(foo bar fubb)
      @dobj.apo_druid_id = z
      expect(@dobj.apo_matches_exactly_one?(apos)).to eq(false)  # Too few.
      apos.push z
      expect(@dobj.apo_matches_exactly_one?(apos)).to eq(true)   # One = just right.
      apos.push z
      expect(@dobj.apo_matches_exactly_one?(apos)).to eq(false)  # Too many.
    end

  end

  ####################

  describe "register()" do

    it "should do nothing if should_register is false" do
      @dobj.project_style[:should_register] = false
      expect(@dobj).not_to receive :register_in_dor
      @dobj.register
    end

    it "can exercise method using stubbed exernal calls" do
      @dobj.project_style[:should_register] = true
      allow(@dobj).to receive(:register_in_dor).and_return(1234)
      expect(@dobj.dor_object).to eq(nil)
      @dobj.register
      expect(@dobj.dor_object).to eq(1234)
    end

    it "can exercise registration_params() and get expected data structure" do
      @dobj.druid = @druid
      @dobj.label = "LabelQuux"
      rps = @dobj.registration_params
      expect(rps).to             be_kind_of Hash
      expect(rps[:source_id]).to be_kind_of Hash
      expect(rps[:tags]).to      be_kind_of Array
      expect(rps[:tags]).to eq(["Project : ProjectBar"])
      expect(rps[:label]).to eq("LabelQuux")
    end

    it "should add a new tag to the registration params if set" do

      @ps[:apply_tag]='Foo : Bar'
      dobj_with_tag = PreAssembly::DigitalObject.new @ps
      rps = dobj_with_tag.registration_params
      expect(rps).to             be_kind_of Hash
      expect(rps[:tags]).to      be_kind_of Array
      expect(rps[:tags]).to eq(["Project : ProjectBar", "Foo : Bar"])

      @ps[:apply_tag]='Foo : Bar'
      dobj_with_tag = PreAssembly::DigitalObject.new @ps
      rps = dobj_with_tag.registration_params
      expect(rps).to             be_kind_of Hash
      expect(rps[:tags]).to      be_kind_of Array
      expect(rps[:tags]).to eq(["Project : ProjectBar", "Foo : Bar"])

      @ps[:apply_tag]=nil
      dobj_with_tag = PreAssembly::DigitalObject.new @ps
      rps = dobj_with_tag.registration_params
      expect(rps).to             be_kind_of Hash
      expect(rps[:tags]).to      be_kind_of Array
      expect(rps[:tags]).to eq(["Project : ProjectBar"])

    end

  end

  ####################

  describe "add_dor_object_to_set()" do

    it "should do nothing when @set_druid_id is false" do
      fake = double('dor_object', :add_relationship => 11, :save => 22)
      @dobj.dor_object = fake
      @dobj.set_druid_id = nil
      expect(@dobj).not_to receive(:add_member_relationship_params)
      expect(@dobj).not_to receive(:add_collection_relationship_params)
      expect(fake).not_to receive :add_relationship
      @dobj.add_dor_object_to_set
    end

    it "should call add_relationship when not null the correct number of times for a single set druid passed in" do
      fake = double('dor_object', :add_relationship => 11, :save => 22)
      @dobj.dor_object = fake
      expect(@dobj).to receive(:add_member_relationship_params).with('druid:mm111nn2222').exactly(1).times
      expect(@dobj).to receive(:add_collection_relationship_params).with('druid:mm111nn2222').exactly(1).times
      expect(fake).to receive(:add_relationship).exactly(2).times
      @dobj.add_dor_object_to_set
    end

    it "should call add_relationship when not null the correct number of times for more than one set druids passed in" do
      fake = double('dor_object', :add_relationship => 11, :save => 22)
      @dobj.dor_object = fake
      @dobj.set_druid_id = ['druid:oo000oo0001','druid:oo000oo0002']
      expect(@dobj).to receive(:add_member_relationship_params).with('druid:oo000oo0001').exactly(1).times
      expect(@dobj).to receive(:add_collection_relationship_params).with('druid:oo000oo0001').exactly(1).times
      expect(@dobj).to receive(:add_member_relationship_params).with('druid:oo000oo0002').exactly(1).times
      expect(@dobj).to receive(:add_collection_relationship_params).with('druid:oo000oo0002').exactly(1).times
      expect(fake).to receive(:add_relationship).exactly(4).times
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
      arps = expect(@dobj.add_member_relationship_params('druid:mm111nn2222')).to eq(exp1)
      arps = expect(@dobj.add_collection_relationship_params('druid:mm111nn2222')).to eq(exp2)
    end

  end

  ####################

  describe "unregister()" do

    before(:each) do
      @dobj.dor_object = 1234
      allow(Assembly::Utils).to receive :delete_from_dor
      allow(Assembly::Utils).to receive :set_workflow_step_to_error
    end

    it "should do nothing unless the digitial object was registered by pre-assembly" do
      expect(@dobj).not_to receive :delete_from_dor
      @dobj.reg_by_pre_assembly = false
      @dobj.unregister
    end

    it "can exercise unregister(), with external calls stubbed" do
      @dobj.reg_by_pre_assembly = true
      @dobj.unregister
      expect(@dobj.dor_object).to eq(nil)
      expect(@dobj.reg_by_pre_assembly).to eq(false)
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
          expect(File.exists?(src)).to eq(true)
          expect(File.exists?(cpy)).to eq(true)
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
          expect(File.exists?(src)).to eq(true)
          expect(File.exists?(cpy)).to eq(true)
          expect(File.symlink?(cpy)).to eq(true)
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
            <file publish="yes" shelve="yes" id="image1.jp2" preserve="yes">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_2" sequence="2">
            <label>Image 2</label>
            <file publish="yes" shelve="yes" id="image1.tif" preserve="yes">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_3" sequence="3">
            <label>Image 3</label>
            <file publish="yes" shelve="yes" id="image2.jp2" preserve="yes">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_4" sequence="4">
            <label>Image 4</label>
            <file publish="yes" shelve="yes" id="image2.tif" preserve="yes">
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
      expect(@dobj.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0 ... m).each { |i| @dobj.object_files[i].exclude_from_content = true }
      ofiles = @dobj.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map { |f| f.relative_path }).to eq(files[m .. -1].sort)
    end

    it "should generate the expected xml text" do
      expect(noko_doc(@dobj.content_md_xml)).to be_equivalent_to @exp_xml
    end

    it "should be able to write the content_metadata XML to a file" do
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join(tmp_area,"metadata",@dobj.content_md_file)

        expect(File.exists?(file_name)).to eq(false)
        @dobj.write_content_metadata
        expect(noko_doc(File.read file_name)).to be_equivalent_to @exp_xml
      end
    end

  end

  #########
  describe "check the druid tree directories and content and metadata locations using both the new style and the old style" do

    it "should have the correct druid tree folders using the new style" do
      @dobj.druid = @druid
      @dobj.new_druid_tree_format = true
      expect(@dobj.druid_tree_dir).to eq('gn/330/dv/6119/gn330dv6119')
      expect(@dobj.metadata_dir).to eq('gn/330/dv/6119/gn330dv6119/metadata')
      expect(@dobj.content_dir).to eq('gn/330/dv/6119/gn330dv6119/content')
    end

    it "should have the correct druid tree folders using the old style" do
      @dobj.druid = @druid
      @dobj.new_druid_tree_format = false
      expect(@dobj.druid_tree_dir).to eq('gn/330/dv/6119')
      expect(@dobj.metadata_dir).to eq('gn/330/dv/6119')
      expect(@dobj.content_dir).to eq('gn/330/dv/6119')
    end

  end

  ####################

  describe "no content metadata generated" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='none'
      @dobj.project_style[:content_structure]='simple_book'
      @dobj.file_attr=nil
      add_object_files('tif')
      add_object_files('jp2')
      @dobj.create_content_metadata
    end

    it "should not generate any xml text" do
      expect(@dobj.content_md_xml).to eq("")
    end

  end

  ####################

  ####################

  describe "bundled by filename, simple book content metadata without file attributes" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='filename'
      @dobj.project_style[:content_structure]='simple_book'
      @dobj.file_attr=nil
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
      expect(noko_doc(@dobj.content_md_xml)).to be_equivalent_to @exp_xml
    end

  end

  ####################

  describe "content metadata generated from object tag in DOR if present and overriding is allowed" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='default'
      @dobj.project_style[:content_structure]='simple_image' # this is the default
      @dobj.project_style[:content_tag_override]=true        # this allows override of content structure
      allow(@dobj).to receive(:content_type_tag).and_return('File')       # this is what the object tag says, so we should get the file type out
      @dobj.project_style[:should_register]=false
      @dobj.file_attr=nil
      add_object_files('tif')
      add_object_files('jp2')
      @dobj.create_content_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <contentMetadata type="file" objectId="gn330dv6119">
          <resource type="file" id="gn330dv6119_1" sequence="1">
            <label>File 1</label>
            <file id="image1.jp2">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="file" id="gn330dv6119_2" sequence="2">
            <label>File 2</label>
            <file id="image1.tif">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="file" id="gn330dv6119_3" sequence="3">
            <label>File 3</label>
            <file id="image2.jp2">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="file" id="gn330dv6119_4" sequence="4">
            <label>File 4</label>
            <file id="image2.tif">
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
      expect(@dobj.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0 ... m).each { |i| @dobj.object_files[i].exclude_from_content = true }
      ofiles = @dobj.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map { |f| f.relative_path }).to eq(files[m .. -1].sort)
    end

    it "should generate the expected xml text" do
      expect(@dobj.content_md_creation_style).to eq(:file)
      expect(noko_doc(@dobj.content_md_xml)).to be_equivalent_to @exp_xml
    end
  end

  ####################
  describe "content metadata generated from object tag in DOR if present but overriding is not allowed" do

    before(:each) do
      @dobj.druid = @druid
      @dobj.content_md_creation[:style]='default'
      @dobj.project_style[:content_structure]='simple_image' # this is the default
      allow(@dobj).to receive(:content_type_tag).and_return('File')       # this is what the object tag says, but it should be ignored since overriding is not allowed
      @dobj.project_style[:should_register]=false
      @dobj.file_attr={'image/jp2'=>{:publish=>'yes',:shelve=>'yes',:preserve=>'no'},'image/tiff'=>{:publish=>'no',:shelve=>'no',:preserve=>'yes'}}
      add_object_files('tif')
      add_object_files('jp2')
      @dobj.create_content_metadata
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <contentMetadata type="image" objectId="gn330dv6119">
          <resource type="image" sequence="1" id="gn330dv6119_1">
            <label>Image 1</label>
            <file publish="yes" preserve="no" shelve="yes" id="image1.jp2">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" sequence="2" id="gn330dv6119_2">
            <label>Image 2</label>
            <file publish="no" preserve="yes" shelve="no" id="image1.tif">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" sequence="3" id="gn330dv6119_3">
            <label>Image 3</label>
            <file publish="yes" preserve="no" shelve="yes" id="image2.jp2">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="image" sequence="4" id="gn330dv6119_4">
            <label>Image 4</label>
            <file publish="no" preserve="yes" shelve="no" id="image2.tif">
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
      expect(@dobj.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0 ... m).each { |i| @dobj.object_files[i].exclude_from_content = true }
      ofiles = @dobj.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map { |f| f.relative_path }).to eq(files[m .. -1].sort)
    end

    it "should generate the expected xml text when overriding is explicitly not allowed" do
      @dobj.project_style[:content_tag_override]=false       # this prevents override of content structure
      expect(@dobj.content_md_creation_style).to eq(:simple_image)
      expect(noko_doc(@dobj.content_md_xml)).to be_equivalent_to @exp_xml
    end

    it "should generate the expected xml text when overriding is not specified" do
      @dobj.project_style[:content_tag_override]=nil       # this prevents override of content structure
      expect(@dobj.content_md_creation_style).to eq(:simple_image)
      expect(noko_doc(@dobj.content_md_xml)).to be_equivalent_to @exp_xml
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
      expect(@dobj).not_to receive :create_desc_metadata_xml
      @dobj.generate_desc_metadata
    end

    it "create_desc_metadata_xml() should generate the expected xml text with the manifest row having a hash with keys as symbols" do
      @dobj.create_desc_metadata_xml
      expect(noko_doc(@dobj.desc_md_xml)).to be_equivalent_to @exp_xml
    end

    it "create_desc_metadata_xml() should generate the expected xml text with the manifest row having a hash with keys as strings" do
      @dobj.manifest_row = {
        'sourceid'    => 'foo-1',
        'label'       => 'this is < a label with an & that will break XML unless it is escaped',
        'year'        => '2012',
        'description' => 'this is a description > another description < other stuff',
        'format'      => 'film',
        'foo'        =>  '123',
        'bar'         => '456',
      }
      @dobj.create_desc_metadata_xml
      expect(noko_doc(@dobj.desc_md_xml)).to be_equivalent_to @exp_xml
    end


    it "should be able to write the desc_metadata XML to a file" do
      @dobj.create_desc_metadata_xml
      Dir.mktmpdir(*@tmp_dir_args) do |tmp_area|
        @dobj.druid_tree_dir = tmp_area
        file_name = File.join(tmp_area, "metadata",@dobj.desc_md_file)
        expect(File.exists?(file_name)).to eq(false)
        @dobj.write_desc_metadata
        expect(noko_doc(File.read file_name)).to be_equivalent_to @exp_xml
      end
    end

    it "should generate descMetadata correctly given a manifest row as loaded from the csv" do
      manifest=PreAssembly::Bundle.import_csv("#{PRE_ASSEMBLY_ROOT}/spec/test_data/bundle_input_a/manifest.csv")
      @dobj.manifest_row = Hash[manifest[2].each_pair.to_a]

      @dobj.desc_md_template_xml = IO.read("#{PRE_ASSEMBLY_ROOT}/spec/test_data/bundle_input_a/mods_template.xml")
      @dobj.create_desc_metadata_xml
      exp_xml = <<-END.gsub(/^ {8}/, '')
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
            <form authority="att">BW film</form>
          </physicalDescription>
        </relatedItem>
        <originInfo>
          <dateCreated>1938, 1956</dateCreated>
        </originInfo>
        <titleInfo>a
            <title>Avus 1938, 1956</title>
        </titleInfo>
        <note>yo, this is a description</note>
        <identifier type="local" displayLabel="Revs ID">foo-2.2</identifier>
        <note type="source note" ID="inst_notes">strip 2 is duplicate; don't scan</note>
        <note type="source note" ID="inst_notes2">strip 2 is duplicate; don't scan</note>
      </mods>
      END

      expect(noko_doc(@dobj.desc_md_xml)).to be_equivalent_to exp_xml
    end

  end

  ####################

  describe "initiate assembly workflow" do

    it "initialize_assembly_workflow() should do nothing if init_assembly_wf is false" do
      @dobj.init_assembly_wf = false
      expect(@dobj).not_to receive :assembly_workflow_url
      @dobj.initialize_assembly_workflow
    end

    it "assembly_workflow_url() should return expected value" do
      @dobj.pid = @pid
      url = @dobj.assembly_workflow_url
      expect(url).to match(/^http.+assemblyWF$/)
      expect(url.include?(@pid)).to eq(true)
    end

    it "assembly_workflow_url() should add the druid: prefix to the pid if it is missing, like it might be in the manifest" do
      @dobj.pid = @pid.gsub('druid:','')
      url = @dobj.assembly_workflow_url
      expect(url).to match(/^http.+assemblyWF$/)
      expect(url.include?(@pid)).to eq(true)
    end

  end

end
