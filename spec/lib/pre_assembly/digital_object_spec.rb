RSpec.describe PreAssembly::DigitalObject do
  subject(:object) { described_class.new(bc.bundle) }

  let(:dru) { 'gn330dv6119' }
  let(:pid) { "druid:#{dru}" }
  let(:bc) { create(:bundle_context, bundle_dir: 'spec/test_data/images_jp2_tif') }
  let(:druid) { DruidTools::Druid.new(pid) }
  let(:tmp_dir_args) { [nil, 'tmp'] }

  before(:all) { FileUtils.rm_rf('log/test_jobs') }

  before do
    allow(bc).to receive(:progress_log_file).and_return(Tempfile.new('images_jp2_tif').path)
    object.object_files = []
  end

  def add_object_files(extension = 'tif')
    (1..2).each do |i|
      f = "image#{i}.#{extension}"
      object.object_files.push PreAssembly::ObjectFile.new(
        "#{object.bundle_dir}/#{dru}/#{f}",
        relative_path: f,
        checksum: i.to_s * 4
      )
    end
  end

  describe '#pre_assemble' do
    before do
      allow(object).to receive(:pid).and_return(pid)
    end

    it 'does not call create_new_version for new_objects' do
      allow(object).to receive(:'openable?').and_return(false)
      allow(object).to receive(:current_object_version).and_return(1)
      expect(object).to receive(:stage_files)
      expect(object).to receive(:generate_content_metadata)
      expect(object).to receive(:generate_technical_metadata)
      expect(object).not_to receive(:create_new_version)
      expect(object).to receive(:initialize_assembly_workflow)
      object.pre_assemble
    end

    it 'throws an exception for existing non-openable objects' do
      allow(object).to receive(:'openable?').and_return(false)
      allow(object).to receive(:current_object_version).and_return(2)
      expect(object).not_to receive(:stage_files)
      exp_msg = "#{pid} can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened"
      expect { object.pre_assemble }.to raise_error(RuntimeError, exp_msg)
    end

    it 'calls create_new_version for existing openable objects' do
      allow(object).to receive(:'openable?').and_return(true)
      allow(object).to receive(:current_object_version).and_return(2)
      expect(object).to receive(:stage_files)
      expect(object).to receive(:generate_content_metadata)
      expect(object).to receive(:generate_technical_metadata)
      expect(object).to receive(:create_new_version)
      expect(object).to receive(:initialize_assembly_workflow)
      object.pre_assemble
    end
  end

  describe '#container_basename' do
    it 'returns expected value' do
      d = 'xx111yy2222'
      object.container = "foo/bar/#{d}"
      expect(object.container_basename).to eq(d)
    end
  end

  describe 'file staging' do
    let(:files) { [1, 2, 3].map { |n| "image#{n}.tif" } }
    let(:tmp_area) do
      Dir.mktmpdir(*tmp_dir_args)
    end

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(object).to receive(:bundle_dir).and_return(tmp_area)
      allow(object).to receive(:assembly_staging_dir).and_return("#{tmp_area}/target")
      allow(object).to receive(:stageable_items).and_return(files.map { |f| File.expand_path("#{tmp_area}/#{f}") })
      object.stageable_items.each { |si| FileUtils.touch si }
      FileUtils.mkdir object.assembly_staging_dir
    end

    after { FileUtils.remove_entry tmp_area }

    it 'is able to copy stageable items successfully' do
      object.stage_files
      # Check outcome: both source and copy should exist.
      files.each_with_index do |f, i|
        src = object.stageable_items[i]
        cpy = File.join(object.content_dir, f)
        expect(File.exist?(src)).to eq(true)
        expect(File.exist?(cpy)).to eq(true)
        expect(File.symlink?(cpy)).to eq(false)
      end
    end

    it 'is able to symlink stageable items successfully' do
      allow(bc).to receive(:staging_style_symlink).and_return(true)
      object.stage_files
      # Check outcome: both source and copy should exist.
      files.each_with_index do |f, i|
        src = object.stageable_items[i]
        cpy = File.join(object.content_dir, f)
        expect(File.exist?(src)).to eq(true)
        expect(File.exist?(cpy)).to eq(true)
        expect(File.symlink?(cpy)).to eq(true)
      end
    end
  end

  describe 'default content metadata' do
    let(:exp_xml) do
      noko_doc <<-END
        <contentMetadata type="image" objectId="gn330dv6119">
          <resource type="image" id="gn330dv6119_1" sequence="1">
            <label>Image 1</label>
            <file id="image1.jp2">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_2" sequence="2">
            <label>Image 2</label>
            <file id="image1.tif">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_3" sequence="3">
            <label>Image 3</label>
            <file id="image2.jp2">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="image" id="gn330dv6119_4" sequence="4">
            <label>Image 4</label>
            <file id="image2.tif">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
        </contentMetadata>
      END
    end

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(object).to receive(:content_type_tag).and_return('')
      allow(bc).to receive(:content_structure).and_return('simple_image')
      add_object_files('tif')
      add_object_files('jp2')
      object.create_content_metadata
    end

    it 'content_object_files() should filter @object_files correctly' do
      # Generate some object_files.
      files = %w[file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif]
      n = files.size
      m = n / 2
      object.object_files = files.map do |f|
        PreAssembly::ObjectFile.new("/path/to/#{f}", relative_path: f)
      end
      # All of them are included in content.
      expect(object.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| object.object_files[i].exclude_from_content = true }
      ofiles = object.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map(&:relative_path)).to eq(files[m..-1].sort)
    end

    it 'generates the expected xml text' do
      expect(noko_doc(object.content_md_xml)).to be_equivalent_to exp_xml
    end

    it 'is able to write the content_metadata XML to a file' do
      Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
        object.druid_tree_dir = tmp_area
        file_name = File.join(tmp_area, 'metadata', object.send(:content_md_file))
        expect(File.exist?(file_name)).to eq(false)
        object.write_content_metadata
        expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
      end
    end
  end

  describe 'druid tree' do
    it 'has the correct folders (using the contemporary style)' do
      allow(object).to receive(:druid).and_return(druid)
      expect(object.druid_tree_dir).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119')
      expect(object.metadata_dir).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/metadata')
      expect(object.content_dir).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/content')
    end
  end

  describe 'bundled by filename, simple book content metadata without file attributes' do
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
      allow(object).to receive(:druid).and_return(druid)
      allow(object).to receive(:content_type_tag).and_return('')
      allow(bc).to receive(:content_structure).and_return('simple_book')
      allow(bc).to receive(:content_md_creation).and_return('filename')
      add_object_files('tif')
      add_object_files('jp2')
      object.create_content_metadata
    end

    it 'generates the expected xml text' do
      expect(noko_doc(object.content_md_xml)).to be_equivalent_to(exp_xml)
    end
  end

  describe 'content metadata generated from object tag in DOR if present and overriding is allowed' do
    let(:exp_xml) do
      noko_doc <<-END
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
      allow(object).to receive(:druid).and_return(druid)
      allow(bc).to receive(:content_structure).and_return('simple_image') # this is the default
      allow(object).to receive(:content_type_tag).and_return('File') # this is what the object tag says, so we should get the file type out
      add_object_files('tif')
      add_object_files('jp2')
      object.create_content_metadata
    end

    it 'content_object_files() should filter @object_files correctly' do
      # Generate some object_files.
      files = %w[file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif]
      n = files.size
      m = n / 2
      object.object_files = files.map do |f|
        PreAssembly::ObjectFile.new("/path/to/#{f}", relative_path: f)
      end
      # All of them are included in content.
      expect(object.content_object_files.size).to eq(n)
      # Now exclude some. Make sure we got correct N of items.
      (0...m).each { |i| object.object_files[i].exclude_from_content = true }
      ofiles = object.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map(&:relative_path)).to eq(files[m..-1].sort)
    end

    it 'generates the expected xml text' do
      expect(object.content_md_creation_style).to eq(:file)
      expect(noko_doc(object.content_md_xml)).to be_equivalent_to(exp_xml)
    end
  end

  describe 'content metadata generated from object tag in DOR if present but overriding is not allowed' do
    let(:exp_xml) do
      noko_doc <<-END
        <contentMetadata type="image" objectId="gn330dv6119">
          <resource type="image" sequence="1" id="gn330dv6119_1">
            <label>Image 1</label>
            <file id="image1.jp2">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" sequence="2" id="gn330dv6119_2">
            <label>Image 2</label>
            <file id="image1.tif">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="image" sequence="3" id="gn330dv6119_3">
            <label>Image 3</label>
            <file id="image2.jp2">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
          <resource type="image" sequence="4" id="gn330dv6119_4">
            <label>Image 4</label>
            <file id="image2.tif">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
        </contentMetadata>
      END
    end

    before do
      allow(bc).to receive(:content_structure).and_return('simple_image') # this is the default
      allow(object).to receive(:druid).and_return(druid)
      allow(object).to receive(:content_type_tag).and_return('File') # this is what the object tag says, but it should be ignored since overriding is not allowed
      add_object_files('tif')
      add_object_files('jp2')
      object.create_content_metadata
    end

    it 'content_object_files() should filter @object_files correctly' do
      # Generate some object_files.
      files = %w[file5.tif file4.tif file3.tif file2.tif file1.tif file0.tif]
      object.object_files = files.map do |f|
        PreAssembly::ObjectFile.new("/path/to/#{f}", relative_path: f)
      end
      # All of them are included in content.
      expect(object.content_object_files.size).to eq(files.size)
      m = files.size / 2
      # Now exclude some. Make sure we got correct M of items.
      (0...m).each { |i| object.object_files[i].exclude_from_content = true }
      ofiles = object.content_object_files
      expect(ofiles.size).to eq(m)
      # Also check their ordering.
      expect(ofiles.map(&:relative_path)).to eq(files[m..-1].sort)
    end
  end

  describe '#openable?' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true, close: true) }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
    end

    it 'checks if the object is openable' do
      expect(dor_services_client_object_version).to receive(:'openable?')
      object.openable?
    end
  end

  describe '#current_object_version' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true, close: true) }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
    end

    it 'checks the current object version' do
      expect(dor_services_client_object_version).to receive(:current)
      object.current_object_version
    end
  end

  describe '#create_new_version' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true, close: true) }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }
    let(:version_options) { { significance: 'major', description: 'pre-assembly re-accession', opening_user_name: object.bundle.bundle_context.user.sunet_id } }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
    end

    it 'opens and closes an object version' do
      expect(dor_services_client_object_version).to receive(:open).with(**version_options)
      expect(dor_services_client_object_version).to receive(:close).with(start_accession: false)
      object.create_new_version
    end
  end

  describe '#initialize_assembly_workflow' do
    subject(:start_workflow) { object.initialize_assembly_workflow }

    before do
      allow(Dor::Config.workflow).to receive(:client).and_return(client)
      allow(object).to receive(:druid).and_return(druid)
    end

    let(:client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true) }
    let(:service_url) { Settings.dor_services_url }

    context 'when api client is successful' do
      it 'starts the assembly workflow' do
        start_workflow
        expect(client).to have_received(:create_workflow_by_name).with(druid.druid, 'assemblyWF')
      end
    end

    context 'when the api client raises' do
      before do
        allow(client).to receive(:create_workflow_by_name).and_raise(StandardError)
      end

      it 'raises an exception' do
        expect { start_workflow }.to raise_error(StandardError)
      end
    end
  end
end
