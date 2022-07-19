# frozen_string_literal: true

RSpec.describe PreAssembly::DigitalObject do
  subject(:object) do
    described_class.new(bc.batch, object_files: [], stager: stager, pid: pid)
  end

  let(:pid) { 'druid:gn330dv6119' }
  let(:stager) { PreAssembly::CopyStager }
  let(:bc) { create(:batch_context, staging_location: 'spec/test_data/images_jp2_tif') }
  let(:druid) { object.druid }
  let(:tmp_dir_args) { [nil, 'tmp'] }

  before(:all) { FileUtils.remove_dir('log/test_jobs') }

  before do
    allow(bc).to receive(:progress_log_file).and_return(Tempfile.new('images_jp2_tif').path)
  end

  describe '#pre_assemble' do
    before do
      allow(StartAccession).to receive(:run)
    end

    it 'calls all methods needed to accession' do
      allow(object).to receive(:openable?).and_return(false)
      allow(object).to receive(:current_object_version).and_return(1)
      expect(object).to receive(:stage_files)
      expect(object).to receive(:update_structural_metadata)
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
        expect(status).to eq(status: 'error', pre_assem_finished: false,
                             message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened")
      end
    end
  end

  describe '#stage_files' do
    let(:files) { [1, 2, 3].map { |n| "image#{n}.tif" } }
    let(:tmp_area) do
      Dir.mktmpdir(*tmp_dir_args)
    end
    let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: object.druid.id) }

    before do
      allow(object).to receive(:staging_location).and_return(tmp_area)
      allow(assembly_directory).to receive(:assembly_staging_dir).and_return("#{tmp_area}/target")
      allow(object).to receive(:stageable_items).and_return(files.map { |f| File.expand_path("#{tmp_area}/#{f}") })
      allow(object).to receive(:assembly_directory).and_return(assembly_directory)
      object.stageable_items.each { |si| FileUtils.touch si }
      assembly_directory.send(:create_object_directories)
    end

    after { FileUtils.remove_entry tmp_area }

    context 'when the copy stager is passed' do
      it 'is able to copy stageable items successfully' do
        object.send(:stage_files)
        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = File.join(assembly_directory.send(:content_dir), f)
          expect(File.exist?(src)).to be(true)
          expect(File.exist?(cpy)).to be(true)
          expect(File.symlink?(cpy)).to be(false)
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
          cpy = File.join(assembly_directory.send(:content_dir), f)
          expect(File.exist?(src)).to be(true)
          expect(File.exist?(cpy)).to be(true)
          expect(File.symlink?(cpy)).to be(true)
        end
      end
    end
  end

  describe '#build_structural' do
    let(:dro) do
      Cocina::RSpec::Factories.build(:dro, type: cocina_type).new(access: { view: 'world' })
    end

    let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: object.druid.id) }

    let(:object_client) do
      instance_double(Dor::Services::Client::Object, find: dro)
    end

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(object_client)
      allow(object).to receive(:assembly_directory).and_return(assembly_directory)
    end

    def add_object_files(extension = 'tif')
      (1..2).each do |i|
        f = "image#{i}.#{extension}"
        options = { relative_path: f, checksum: i.to_s * 4 }

        object.object_files.push PreAssembly::ObjectFile.new("#{object.staging_location}/gn330dv6119/#{f}", options)
      end
    end

    describe 'default structural metadata (image)' do
      let(:cocina_type) { Cocina::Models::ObjectType.image }
      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Image 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: 'image1.jp2',
                                                  filename: 'image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Image 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image1.tif',
                                                  filename: 'image1.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_3',
                       label: 'Image 3',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/3',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_4',
                       label: 'Image 4',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/4',
                                                  label: 'image2.tif',
                                                  filename: 'image2.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        add_object_files('tif')
        add_object_files('jp2')
        allow(SecureRandom).to receive(:uuid).and_return('1', '2', '3', '4')
      end

      around do |example|
        RSpec::Mocks.with_temporary_scope do
          Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
            allow(assembly_directory).to receive(:druid_tree_dir).and_return(tmp_area)
            example.run
          end
        end
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'map structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.map }

      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Image 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: 'image1.jp2',
                                                  filename: 'image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Image 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('map')
        add_object_files('jp2')
        allow(SecureRandom).to receive(:uuid).and_return('1', '2')
      end

      around do |example|
        RSpec::Mocks.with_temporary_scope do
          Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
            allow(assembly_directory).to receive(:druid_tree_dir).and_return(tmp_area)
            example.run
          end
        end
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'book (ltr) structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.book }

      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/page',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Page 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: 'image1.jp2',
                                                  filename: 'image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/page',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Page 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [{ members: [], viewingDirection: 'left-to-right' }],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('simple_book')
        add_object_files('jp2')
        allow(SecureRandom).to receive(:uuid).and_return('1', '2')
      end

      around do |example|
        RSpec::Mocks.with_temporary_scope do
          Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
            allow(assembly_directory).to receive(:druid_tree_dir).and_return(tmp_area)
            example.run
          end
        end
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'book (rtl) structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.book }

      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/page',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Page 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: 'image1.jp2',
                                                  filename: 'image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/page',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Page 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [{ members: [], viewingDirection: 'right-to-left' }],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('simple_book_rtl')
        add_object_files('jp2')
        allow(SecureRandom).to receive(:uuid).and_return('1', '2')
      end

      around do |example|
        RSpec::Mocks.with_temporary_scope do
          Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
            allow(assembly_directory).to receive(:druid_tree_dir).and_return(tmp_area)
            example.run
          end
        end
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'webarchive-seed structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.webarchive_seed }

      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Image 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: 'image1.jp2',
                                                  filename: 'image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Image 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('webarchive-seed')
        add_object_files('jp2')
        allow(SecureRandom).to receive(:uuid).and_return('1', '2')
      end

      around do |example|
        RSpec::Mocks.with_temporary_scope do
          Dir.mktmpdir(*tmp_dir_args) do |tmp_area|
            allow(assembly_directory).to receive(:druid_tree_dir).and_return(tmp_area)
            example.run
          end
        end
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'grouped by filename, simple book structural metadata without file attributes' do
      let(:cocina_type) { Cocina::Models::ObjectType.book }

      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/page',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Page 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: 'image1.jp2',
                                                  filename: 'image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image1.tif',
                                                  filename: 'image1.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/page',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Page 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/3',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/4',
                                                  label: 'image2.tif',
                                                  filename: 'image2.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } }],
          hasMemberOrders: [{ members: [], viewingDirection: 'left-to-right' }],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('simple_book')
        allow(bc).to receive(:content_md_creation).and_return('filename')
        add_object_files('tif')
        add_object_files('jp2')
        allow(SecureRandom).to receive(:uuid).and_return('1', '2', '3', '4')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end
  end

  describe '#content_md_creation_style' do
    before do
      allow(object).to receive(:object_type).and_return(Cocina::Models::ObjectType.object)
    end

    it 'generates the expected xml text' do
      expect(object.content_md_creation_style).to eq(:file)
    end
  end

  describe '#openable?' do
    let(:dor_services_client_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
    let(:dor_services_client_object) { instance_double(Dor::Services::Client::Object, version: dor_services_client_object_version) }

    before do
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
      allow(Dor::Services::Client).to receive(:object).and_return(dor_services_client_object)
    end

    it 'checks the current object version' do
      object.send(:current_object_version)
      expect(dor_services_client_object_version).to have_received(:current)
    end
  end
end
