RSpec.describe PreAssembly::DigitalObject do
  let(:dru) { 'gn330dv6119' }
  let(:pid) { "druid:#{dru}" }
  let(:ps) {
    {
      # :apo_druid_id  => 'druid:qq333xx4444',
      # :set_druid_id  => 'druid:mm111nn2222',
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      :publish_attr  => { 'default' => { :publish => 'yes', :shelve => 'yes', :preserve => 'yes' } },
      :project_style => {},
      :content_md_creation => {},
      :bundle_dir => 'spec/test_data/bundle_input_g',
      :staging_style => 'copy'
    }
  }
  let(:dobj) { described_class.new(ps) }
  let(:druid) { DruidTools::Druid.new(pid) }
  let(:tmp_dir_args) { [nil, 'tmp'] }

  before { dobj.object_files = [] }

  def add_object_files(extension = 'tif')
    (1..2).each do |i|
      f = "image#{i}.#{extension}"
      dobj.object_files.push PreAssembly::ObjectFile.new(
        :path                 => "#{dobj.bundle_dir}/#{dru}/#{f}",
        :relative_path        => f,
        :exclude_from_content => false,
        :checksum             => "#{i}" * 4
      )
    end
  end

  describe '#container_basename' do
    it 'returns expected value' do
      d = 'xx111yy2222'
      dobj.container = "foo/bar/#{d}"
      expect(dobj.container_basename).to eq(d)
    end
  end

  describe "file staging" do
    it "is able to copy stageable items successfully" do
      allow(dobj).to receive(:druid).and_return(druid)

      Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
        # Add some stageable items to the digital object, and create those files.
        files                 = [1, 2, 3].map { |n| "image#{n}.tif" }
        dobj.bundle_dir      = tmp_area
        dobj.staging_dir     = "#{tmp_area}/target"
        dobj.stageable_items = files.map { |f| File.expand_path("#{tmp_area}/#{f}") }
        dobj.stageable_items.each { |si| FileUtils.touch si }
        dobj.staging_style = 'copy'

        # Stage the files via copy.
        FileUtils.mkdir dobj.staging_dir
        dobj.stage_files

        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = dobj.stageable_items[i]
          cpy = File.join dobj.content_dir, f
          expect(File.exist?(src)).to eq(true)
          expect(File.exist?(cpy)).to eq(true)
        end
      end
    end

    it "is able to symlink stageable items successfully" do
      allow(dobj).to receive(:druid).and_return(druid)

      Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
        # Add some stageable items to the digital object, and create those files.
        files = [1, 2, 3].map { |n| "image#{n}.tif" }
        dobj.bundle_dir      = tmp_area
        dobj.staging_dir     = "#{tmp_area}/target"
        dobj.stageable_items = files.map { |f| File.expand_path("#{tmp_area}/#{f}") }
        dobj.stageable_items.each { |si| FileUtils.touch si }
        dobj.staging_style = 'symlink'

        # Stage the files via symlink.
        FileUtils.mkdir dobj.staging_dir
        dobj.stage_files

        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = dobj.stageable_items[i]
          cpy = File.join dobj.content_dir, f
          expect(File.exist?(src)).to eq(true)
          expect(File.exist?(cpy)).to eq(true)
          expect(File.symlink?(cpy)).to eq(true)
        end
      end
    end
  end

  describe "default content metadata" do
    let(:exp_xml) do
      noko_doc <<-END
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
    end

    before do
      allow(dobj).to receive(:druid).and_return(druid)
      dobj.content_md_creation[:style] = 'default'
      dobj.project_style[:content_structure] = 'simple_image'
      add_object_files('tif')
      add_object_files('jp2')
      dobj.create_content_metadata
    end

    it "content_object_files() should filter @object_files correctly" do
      # Generate some object_files.
      files = %w(file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif)
      n = files.size
      m = n / 2
      dobj.object_files = files.map do |f|
        PreAssembly::ObjectFile.new(:exclude_from_content => false, :relative_path => f)
      end
      # All of them are included in content.
      expect(dobj.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| dobj.object_files[i].exclude_from_content = true }
      ofiles = dobj.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map { |f| f.relative_path }).to eq(files[m..-1].sort)
    end

    it "generates the expected xml text" do
      expect(noko_doc(dobj.content_md_xml)).to be_equivalent_to exp_xml
    end

    it "is able to write the content_metadata XML to a file" do
      Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
        dobj.druid_tree_dir = tmp_area
        file_name = File.join(tmp_area, "metadata", dobj.content_md_file)
        expect(File.exist?(file_name)).to eq(false)
        dobj.write_content_metadata
        expect(noko_doc(File.read file_name)).to be_equivalent_to exp_xml
      end
    end
  end

  describe 'druid tree' do
    it 'has the correct folders (using the contemporary style)' do
      allow(dobj).to receive(:druid).and_return(druid)
      expect(dobj.druid_tree_dir).to eq('gn/330/dv/6119/gn330dv6119')
      expect(dobj.metadata_dir).to eq('gn/330/dv/6119/gn330dv6119/metadata')
      expect(dobj.content_dir).to eq('gn/330/dv/6119/gn330dv6119/content')
    end
  end

  describe "no content metadata generated" do
    before do
      allow(dobj).to receive(:druid).and_return(druid)
      dobj.content_md_creation[:style] = 'none'
      dobj.project_style[:content_structure] = 'simple_book'
      dobj.file_attr = nil
      add_object_files('tif')
      add_object_files('jp2')
      dobj.create_content_metadata
    end

    it "does not generate any xml text" do
      expect(dobj.content_md_xml).to eq("")
    end
  end

  describe "bundled by filename, simple book content metadata without file attributes" do
    let(:exp_xml) do
      noko_doc <<-END
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
    end

    before do
      allow(dobj).to receive(:druid).and_return(druid)
      dobj.content_md_creation[:style] = 'filename'
      dobj.project_style[:content_structure] = 'simple_book'
      dobj.file_attr = nil
      add_object_files('tif')
      add_object_files('jp2')
      dobj.create_content_metadata
    end

    it "generates the expected xml text" do
      expect(noko_doc(dobj.content_md_xml)).to be_equivalent_to(exp_xml)
    end
  end

  describe "content metadata generated from object tag in DOR if present and overriding is allowed" do
    let(:exp_xml) do
      noko_doc <<-END
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
    end

    before do
      allow(dobj).to receive(:druid).and_return(druid)
      dobj.content_md_creation[:style] = 'default'
      dobj.project_style[:content_structure] = 'simple_image' # this is the default
      dobj.project_style[:content_tag_override] = true        # this allows override of content structure
      allow(dobj).to receive(:content_type_tag).and_return('File') # this is what the object tag says, so we should get the file type out
      dobj.file_attr = nil
      add_object_files('tif')
      add_object_files('jp2')
      dobj.create_content_metadata
    end

    it "content_object_files() should filter @object_files correctly" do
      # Generate some object_files.
      files = %w(file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif)
      n = files.size
      m = n / 2
      dobj.object_files = files.map do |f|
        PreAssembly::ObjectFile.new(:exclude_from_content => false, :relative_path => f)
      end
      # All of them are included in content.
      expect(dobj.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| dobj.object_files[i].exclude_from_content = true }
      ofiles = dobj.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map { |f| f.relative_path }).to eq(files[m..-1].sort)
    end

    it "generates the expected xml text" do
      expect(dobj.content_md_creation_style).to eq(:file)
      expect(noko_doc(dobj.content_md_xml)).to be_equivalent_to(exp_xml)
    end
  end

  describe "content metadata generated from object tag in DOR if present but overriding is not allowed" do
    let(:exp_xml) do
      noko_doc <<-END
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
    end

    before do
      allow(dobj).to receive(:druid).and_return(druid)
      dobj.content_md_creation[:style] = 'default'
      dobj.project_style[:content_structure] = 'simple_image' # this is the default
      allow(dobj).to receive(:content_type_tag).and_return('File') # this is what the object tag says, but it should be ignored since overriding is not allowed
      dobj.file_attr = { 'image/jp2' => { :publish => 'yes', :shelve => 'yes', :preserve => 'no' }, 'image/tiff' => { :publish => 'no', :shelve => 'no', :preserve => 'yes' } }
      add_object_files('tif')
      add_object_files('jp2')
      dobj.create_content_metadata
    end

    it "content_object_files() should filter @object_files correctly" do
      # Generate some object_files.
      files = %w(file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif)
      n = files.size
      m = n / 2
      dobj.object_files = files.map do |f|
        PreAssembly::ObjectFile.new(:exclude_from_content => false, :relative_path => f)
      end
      # All of them are included in content.
      expect(dobj.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| dobj.object_files[i].exclude_from_content = true }
      ofiles = dobj.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map { |f| f.relative_path }).to eq(files[m..-1].sort)
    end

    it "generates the expected xml text when overriding is explicitly not allowed" do
      dobj.project_style[:content_tag_override] = false # this prevents override of content structure
      expect(dobj.content_md_creation_style).to eq(:simple_image)
      expect(noko_doc(dobj.content_md_xml)).to be_equivalent_to exp_xml
    end

    it "generates the expected xml text when overriding is not specified" do
      dobj.project_style[:content_tag_override] = nil # this prevents override of content structure
      expect(dobj.content_md_creation_style).to eq(:simple_image)
      expect(noko_doc(dobj.content_md_xml)).to be_equivalent_to exp_xml
    end
  end

  describe '#assembly_workflow_url' do
    it 'returns expected value' do
      allow(dobj).to receive(:pid).and_return(pid)
      expect(dobj.assembly_workflow_url).to match(/^http.+assemblyWF$/).and include(pid)
    end

    it 'adds the druid: prefix to the pid if it is missing' do
      allow(dobj).to receive(:pid).and_return(pid.gsub('druid:', ''))
      expect(dobj.assembly_workflow_url).to match(/^http.+assemblyWF$/).and include(pid)
    end
  end
end
