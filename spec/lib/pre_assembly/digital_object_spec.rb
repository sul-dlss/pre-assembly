# frozen_string_literal: true

RSpec.describe PreAssembly::DigitalObject do
  subject(:object) do
    described_class.new(bc.batch, object_files: [], stager: stager, dark: false)
  end

  let(:dru) { 'gn330dv6119' }
  let(:pid) { "druid:#{dru}" }
  let(:stager) { PreAssembly::CopyStager }
  let(:bc) { create(:batch_context, bundle_dir: 'spec/test_data/images_jp2_tif') }
  let(:druid) { DruidTools::Druid.new(pid) }
  let(:tmp_dir_args) { [nil, 'tmp'] }

  before(:all) { FileUtils.rm_rf('log/test_jobs') }

  before do
    allow(bc).to receive(:progress_log_file).and_return(Tempfile.new('images_jp2_tif').path)
  end

  def add_object_files(extension = 'tif', all_files_public: false)
    (1..2).each do |i|
      f = "image#{i}.#{extension}"
      options = { relative_path: f, checksum: i.to_s * 4 }
      options[:file_attributes] = { preserve: 'yes', shelve: 'yes', publish: 'yes' } if all_files_public

      object.object_files.push PreAssembly::ObjectFile.new("#{object.bundle_dir}/#{dru}/#{f}", options)
    end
  end

  describe '#pre_assemble' do
    before do
      allow(object).to receive(:pid).and_return(pid)
      allow(StartAccession).to receive(:run)
    end

    it 'calls all methods needed to accession' do
      allow(object).to receive(:openable?).and_return(false)
      allow(object).to receive(:current_object_version).and_return(1)
      expect(object).to receive(:stage_files)
      expect(object).to receive(:generate_content_metadata)
      object.pre_assemble
      expect(StartAccession).to have_received(:run)
    end

    context 'when the object is not openable' do
      before do
        allow(object).to receive(:openable?).and_return(false)
        allow(object).to receive(:current_object_version).and_return(2)
      end

      let(:status) { object.pre_assemble }

      it 'logs an error for existing non-openable objects' do
        expect(object).not_to receive(:stage_files)
        expect(status).to eq(status: 'error',
                             message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened")
      end
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

  describe '#create_content_metadata' do
    describe 'default content metadata (image)' do
      let(:exp_xml) do
        noko_doc <<-XML
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
        XML
      end

      let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
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
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to exp_xml
      end

      it 'is able to write the content_metadata XML to a file' do
        assembly_directory.create_object_directories
        file_name = object.send(:assembly_directory).content_metadata_file
        expect(File.exist?(file_name)).to eq(false)
        object.send(:generate_content_metadata, false)
        expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
      end
    end

    describe 'map content metadata' do
      let(:exp_xml) do
        noko_doc <<-XML
          <contentMetadata type="map" objectId="gn330dv6119">
            <resource type="image" id="gn330dv6119_1" sequence="1">
              <label>Image 1</label>
              <file id="image1.jp2">
                <checksum type="md5">1111</checksum>
              </file>
            </resource>
            <resource type="image" id="gn330dv6119_2" sequence="2">
              <label>Image 2</label>
              <file id="image2.jp2">
                <checksum type="md5">2222</checksum>
              </file>
            </resource>
          </contentMetadata>
        XML
      end

      let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
        allow(bc).to receive(:content_structure).and_return('map')
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
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to exp_xml
      end

      it 'is able to write the content_metadata XML to a file' do
        assembly_directory.create_object_directories
        file_name = object.send(:assembly_directory).content_metadata_file
        expect(File.exist?(file_name)).to eq(false)
        object.send(:generate_content_metadata, false)
        expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
      end
    end

    describe 'book (ltr) content metadata' do
      let(:exp_xml) do
        noko_doc <<-XML
          <contentMetadata type="book" objectId="gn330dv6119">
            <bookData readingOrder="ltr"/>
            <resource type="page" id="gn330dv6119_1" sequence="1">
              <label>Page 1</label>
              <file id="image1.jp2">
                <checksum type="md5">1111</checksum>
              </file>
            </resource>
            <resource type="page" id="gn330dv6119_2" sequence="2">
              <label>Page 2</label>
              <file id="image2.jp2">
                <checksum type="md5">2222</checksum>
              </file>
            </resource>
          </contentMetadata>
        XML
      end

      let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
        allow(bc).to receive(:content_structure).and_return('simple_book')
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
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to exp_xml
      end

      it 'is able to write the content_metadata XML to a file' do
        assembly_directory.create_object_directories
        file_name = object.send(:assembly_directory).content_metadata_file
        expect(File.exist?(file_name)).to eq(false)
        object.send(:generate_content_metadata, false)
        expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
      end
    end

    describe 'book (rtl) content metadata' do
      let(:exp_xml) do
        noko_doc <<-XML
          <contentMetadata type="book" objectId="gn330dv6119">
            <bookData readingOrder="rtl"/>
            <resource type="page" id="gn330dv6119_1" sequence="1">
              <label>Page 1</label>
              <file id="image1.jp2">
                <checksum type="md5">1111</checksum>
              </file>
            </resource>
            <resource type="page" id="gn330dv6119_2" sequence="2">
              <label>Page 2</label>
              <file id="image2.jp2">
                <checksum type="md5">2222</checksum>
              </file>
            </resource>
          </contentMetadata>
        XML
      end

      let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
        allow(bc).to receive(:content_structure).and_return('simple_book_rtl')
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
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to exp_xml
      end

      it 'is able to write the content_metadata XML to a file' do
        assembly_directory.create_object_directories
        file_name = object.send(:assembly_directory).content_metadata_file
        expect(File.exist?(file_name)).to eq(false)
        object.send(:generate_content_metadata, false)
        expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
      end
    end

    describe 'webarchive-seed content metadata' do
      let(:exp_xml) do
        noko_doc <<-XML
          <contentMetadata type="webarchive-seed" objectId="gn330dv6119">
            <resource type="image" id="gn330dv6119_1" sequence="1">
              <label>Image 1</label>
              <file id="image1.jp2">
                <checksum type="md5">1111</checksum>
              </file>
            </resource>
            <resource type="image" id="gn330dv6119_2" sequence="2">
              <label>Image 2</label>
              <file id="image2.jp2">
                <checksum type="md5">2222</checksum>
              </file>
            </resource>
          </contentMetadata>
        XML
      end

      let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: druid.id) }

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
        allow(bc).to receive(:content_structure).and_return('webarchive-seed')
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
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to exp_xml
      end

      it 'is able to write the content_metadata XML to a file' do
        assembly_directory.create_object_directories
        file_name = object.send(:assembly_directory).content_metadata_file
        expect(File.exist?(file_name)).to eq(false)
        object.send(:generate_content_metadata, false)
        expect(noko_doc(File.read(file_name))).to be_equivalent_to exp_xml
      end
    end

    describe 'grouped by filename, simple book content metadata without file attributes' do
      let(:exp_xml) do
        noko_doc <<-XML
        <contentMetadata type="book" objectId="gn330dv6119">
          <bookData readingOrder="ltr"/>
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
        XML
      end

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
        allow(bc).to receive(:content_structure).and_return('simple_book')
        allow(bc).to receive(:content_md_creation).and_return('filename')
        add_object_files('tif')
        add_object_files('jp2')
      end

      it 'generates the expected xml text' do
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to(exp_xml)
      end
    end

    describe 'with file attributes' do
      let(:exp_xml) do
        noko_doc <<-XML
        <contentMetadata type="book" objectId="gn330dv6119">
          <bookData readingOrder="ltr"/>
          <resource type="page" sequence="1" id="gn330dv6119_1">
            <label>Page 1</label>
            <file id="image1.jp2" preserve="yes" shelve="yes" publish="yes">
              <checksum type="md5">1111</checksum>
            </file>
            <file id="image1.tif" preserve="yes" shelve="yes" publish="yes">
              <checksum type="md5">1111</checksum>
            </file>
          </resource>
          <resource type="page" sequence="2" id="gn330dv6119_2">
            <label>Page 2</label>
            <file id="image2.jp2" preserve="yes" shelve="yes" publish="yes">
              <checksum type="md5">2222</checksum>
            </file>
            <file id="image2.tif" preserve="yes" shelve="yes" publish="yes">
              <checksum type="md5">2222</checksum>
            </file>
          </resource>
        </contentMetadata>
        XML
      end

      let(:bc) { create(:batch_context, :public_files, bundle_dir: 'spec/test_data/images_jp2_tif') }

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(object).to receive(:object_type).and_return('')
        allow(bc).to receive(:content_structure).and_return('simple_book')
        allow(bc).to receive(:content_md_creation).and_return('filename')
        add_object_files('tif', all_files_public: true)
        add_object_files('jp2', all_files_public: true)
      end

      it 'generates the expected xml text' do
        expect(object.send(:create_content_metadata, true)).to be_equivalent_to(exp_xml)
      end
    end

    describe 'content metadata generated from object tag in DOR if present and overriding is allowed' do
      let(:exp_xml) do
        noko_doc <<-XML
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
        XML
      end

      before do
        allow(object).to receive(:druid).and_return(druid)
        allow(bc).to receive(:content_structure).and_return('simple_image') # this is the default
        allow(object).to receive(:object_type).and_return(Cocina::Models::ObjectType.object) # this is what the object tag says, so we should get the file type out
        add_object_files('tif')
        add_object_files('jp2')
      end

      it 'generates the expected xml text' do
        expect(object.content_md_creation_style).to eq(:file)
        expect(noko_doc(object.send(:create_content_metadata, false))).to be_equivalent_to(exp_xml)
      end
    end
  end

  describe '#openable?' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
    end

    it 'checks if the object is openable' do
      object.send(:openable?)
      expect(dor_services_client_object_version).to have_received(:openable?)
    end
  end

  describe '#current_object_version' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, current: '9') }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }

    before do
      allow(object).to receive(:druid).and_return(druid)
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
    end

    it 'checks the current object version' do
      object.send(:current_object_version)
      expect(dor_services_client_object_version).to have_received(:current)
    end
  end
end
