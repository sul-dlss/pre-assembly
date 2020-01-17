# frozen_string_literal: true

RSpec.describe PreAssembly::DigitalObject do
  subject(:object) do
    described_class.new(bc.bundle, object_files: [], stager: stager)
  end

  let(:dru) { 'gn330dv6119' }
  let(:pid) { "druid:#{dru}" }
  let(:stager) { PreAssembly::CopyStager }
  let(:bc) { create(:bundle_context, bundle_dir: 'spec/test_data/images_jp2_tif') }
  let(:druid) { DruidTools::Druid.new(pid) }
  let(:tmp_dir_args) { [nil, 'tmp'] }

  before(:all) { FileUtils.rm_rf('log/test_jobs') }

  before do
    allow(bc).to receive(:progress_log_file).and_return(Tempfile.new('images_jp2_tif').path)
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
      expect(object).not_to receive(:create_new_version)
      expect(object).to receive(:initialize_assembly_workflow)
      object.pre_assemble
    end

    context 'when the object is not openable' do
      before do
        allow(object).to receive(:'openable?').and_return(false)
        allow(object).to receive(:current_object_version).and_return(2)
      end

      let(:status) { object.pre_assemble }

      it 'logs an error for existing non-openable objects' do
        expect(object).not_to receive(:stage_files)
        expect(status).to eq(status: 'error',
                             message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened")
      end
    end

    it 'calls create_new_version for existing openable objects' do
      allow(object).to receive(:'openable?').and_return(true)
      allow(object).to receive(:current_object_version).and_return(2)
      expect(object).to receive(:stage_files)
      expect(object).to receive(:generate_content_metadata)
      expect(object).to receive(:create_new_version)
      expect(object).to receive(:initialize_assembly_workflow)
      object.pre_assemble
    end
  end

  describe '#stage_files' do
    let(:files) { [1, 2, 3].map { |n| "image#{n}.tif" } }
    let(:tmp_area) do
      Dir.mktmpdir(*tmp_dir_args)
    end
    let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(object).to receive(:bundle_dir).and_return(tmp_area)
      allow(assembly_directory).to receive(:assembly_staging_dir).and_return("#{tmp_area}/target")
      allow(object).to receive(:stageable_items).and_return(files.map { |f| File.expand_path("#{tmp_area}/#{f}") })
      allow(object).to receive(:assembly_directory).and_return(assembly_directory)
      object.stageable_items.each { |si| FileUtils.touch si }
      assembly_directory.create_object_directories
    end

    after { FileUtils.remove_entry tmp_area }

    context 'when the copy stager is passed' do
      it 'is able to copy stageable items successfully' do
        object.send(:stage_files)
        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = File.join(assembly_directory.content_dir, f)
          expect(File.exist?(src)).to eq(true)
          expect(File.exist?(cpy)).to eq(true)
          expect(File.symlink?(cpy)).to eq(false)
        end
      end
    end

    context 'when the link stager is passed' do
      let(:stager) { PreAssembly::LinkStager }

      it 'is able to symlink stageable items successfully' do
        object.send(:stage_files)
        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = File.join(assembly_directory.content_dir, f)
          expect(File.exist?(src)).to eq(true)
          expect(File.exist?(cpy)).to eq(true)
          expect(File.symlink?(cpy)).to eq(true)
        end
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

    let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(object).to receive(:content_type_tag).and_return('')
      allow(bc).to receive(:content_structure).and_return('simple_image')
      add_object_files('tif')
      add_object_files('jp2')
      allow(object).to receive(:assembly_directory).and_return(assembly_directory)
    end

    around do |example|
      RSpec::Mocks.with_temporary_scope do
        Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
          allow(assembly_directory).to receive(:druid_tree_dir).and_return(tmp_area)
          example.run
        end
      end
    end

    it 'generates the expected xml text' do
      expect(noko_doc(object.send(:create_content_metadata))).to be_equivalent_to exp_xml
    end

    it 'is able to write the content_metadata XML to a file' do
      assembly_directory.create_object_directories
      file_name = object.send(:assembly_directory).content_metadata_file
      expect(File.exist?(file_name)).to eq(false)
      object.send(:generate_content_metadata)
      expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
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
    end

    it 'generates the expected xml text' do
      expect(noko_doc(object.send(:create_content_metadata))).to be_equivalent_to(exp_xml)
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
    end

    it 'generates the expected xml text' do
      expect(object.content_md_creation_style).to eq(:file)
      expect(noko_doc(object.send(:create_content_metadata))).to be_equivalent_to(exp_xml)
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
      object.send(:openable?)
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
      object.send(:current_object_version)
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
      object.send(:create_new_version)
    end
  end

  describe '#initialize_assembly_workflow' do
    subject(:start_workflow) { object.send(:initialize_assembly_workflow) }

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(object_client)
      allow(Dor::Config.workflow).to receive(:client).and_return(client)
      allow(object).to receive(:druid).and_return(druid)
    end

    let(:client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true) }
    let(:version_client) { instance_double(Dor::Services::Client::ObjectVersion, current: '5') }
    let(:object_client) { instance_double(Dor::Services::Client::Object, version: version_client) }
    let(:service_url) { Settings.dor_services_url }

    context 'when api client is successful' do
      it 'starts the assembly workflow' do
        start_workflow
        expect(client).to have_received(:create_workflow_by_name).with(druid.druid, 'assemblyWF', version: 5)
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
