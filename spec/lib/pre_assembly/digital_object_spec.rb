# frozen_string_literal: true

RSpec.describe PreAssembly::DigitalObject do
  subject(:object) do
    described_class.new(job_run.batch, object_files: [], stager:, pid:)
  end

  let(:pid) { 'druid:gn330dv6119' }
  let(:stager) { PreAssembly::CopyStager }
  let(:bc) { create(:batch_context, staging_location: 'spec/fixtures/images_jp2_tif') }
  let(:job_run) { create(:job_run, :preassembly, batch_context: bc) }
  let(:druid) { object.druid }
  let(:tmp_dir_args) { [nil, 'tmp'] }
  let(:tmp_area) do
    File.expand_path(Dir.mktmpdir(*tmp_dir_args))
  end
  let(:assembly_directory) { PreAssembly::AssemblyDirectory.new(druid_id: object.druid.id, base_path: tmp_area, content_structure:) }
  let(:object_client) { instance_double(Dor::Services::Client::Object, version: version_client) }
  let(:version_client) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true, current: '3', status: version_status) }
  let(:version_status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, open?: true) }

  before(:all) { FileUtils.remove_dir('log/test_jobs') if File.directory?('log/test_jobs') }
  after { FileUtils.remove_entry tmp_area }

  before do
    allow(bc).to receive(:progress_log_file).and_return(Tempfile.new('images_jp2_tif').path)
    allow(Dor::Services::Client).to receive(:object).and_return(object_client)
    allow(PreAssembly::FileIdentifierGenerator).to receive(:generate).and_return(
      'https://cocina.sul.stanford.edu/file/1',
      'https://cocina.sul.stanford.edu/file/2',
      'https://cocina.sul.stanford.edu/file/3',
      'https://cocina.sul.stanford.edu/file/4'
    )
  end

  describe '#pre_assemble' do
    let(:status) { object.pre_assemble }

    before do
      allow(StartAccession).to receive(:run)
    end

    it 'calls all methods needed to accession' do
      allow(object).to receive_messages(accessioning?: false, openable?: false, current_object_version: 1, content_md_creation_style: :simple_image)
      expect(object).to receive(:stage_files)
      expect(object).to receive(:update_structural_metadata)
      expect(status).to eq({ pre_assem_finished: true,
                             status: 'success',
                             version: 3 })
      expect(StartAccession).to have_received(:run)
    end

    context 'when the object is not openable' do
      before do
        allow(object).to receive_messages(accessioning?: false)
      end

      let(:version_client) { instance_double(Dor::Services::Client::ObjectVersion, openable?: false, current: 2, status: version_status) }
      let(:version_status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, open?: false) }

      it 'logs an error for existing non-openable objects' do
        expect(object).not_to receive(:stage_files)
        expect(status).to eq(status: 'error', pre_assem_finished: false,
                             message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened")
      end
    end

    context 'when the object is already in accessioning' do
      before do
        allow(object).to receive_messages(accessioning?: true, current_object_version: 1)
      end

      it 'logs an error for objects in accessioning' do
        expect(object).not_to receive(:stage_files)
        expect(status).to eq(status: 'error', pre_assem_finished: false,
                             message: 'cannot accession when object is already in the process of accessioning')
      end
    end
  end

  describe '#stage_files' do
    let(:files) { ['image1.tif', 'image2.tif', 'subfolder/image1.tif'] }
    let(:content_structure) { 'simple_image' }

    before do
      allow(object).to receive_messages(staging_location: tmp_area, stageable_items: files.map { |f| File.expand_path("#{tmp_area}/#{f}") }, assembly_directory:)
      allow(assembly_directory).to receive(:assembly_staging_dir).and_return("#{tmp_area}/target")
      # setup the file structure defined above in a hierarchy
      object.stageable_items.each do |si|
        FileUtils.mkdir_p File.dirname(si)
        FileUtils.touch si
        FileUtils.chmod 0o0600, si
      end
      assembly_directory.send(:create_object_directories)
    end

    context 'when the copy stager is passed' do
      it 'is able to copy stageable items successfully' do
        # source exists, but not copy yet
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = assembly_directory.path_for(f)
          expect(File.exist?(src)).to be(true)
          expect(File.exist?(cpy)).to be(false)
          expect(File.world_readable?(cpy)).to be_nil
          expect(File.symlink?(cpy)).to be(false)
        end
        object.send(:stage_files)
        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = assembly_directory.path_for(f)
          expect(File.exist?(src)).to be(true)
          expect(File.exist?(cpy)).to be(true)
          expect(File.world_readable?(cpy)).not_to be_nil # return value is a platform-dependent integer
          expect(File.symlink?(cpy)).to be(false)
        end
      end
    end

    context 'when the link stager is passed' do
      let(:stager) { PreAssembly::LinkStager }

      it 'is able to symlink stageable items successfully' do
        # source exists, but not copy yet
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = assembly_directory.path_for(f)
          expect(File.exist?(src)).to be(true)
          expect(File.exist?(cpy)).to be(false)
          expect(File.symlink?(cpy)).to be(false)
        end
        object.send(:stage_files)
        # Check outcome: both source and copy should exist.
        files.each_with_index do |f, i|
          src = object.stageable_items[i]
          cpy = assembly_directory.path_for(f)
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

    let(:object_client) do
      instance_double(Dor::Services::Client::Object, find: dro, version: version_client)
    end

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(object_client)
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

    def add_object_files(extension:, num: 2, rel_path: '')
      (1..num).each do |i|
        f = "#{rel_path}image#{i}.#{extension}"
        options = { relative_path: f, checksum: i.to_s * 4 }

        object.object_files.push PreAssembly::ObjectFile.new("#{object.staging_location}/#{druid.id}/#{f}", options)
      end
    end

    describe 'group by filename structural metadata (image)' do
      let(:cocina_type) { Cocina::Models::ObjectType.image }
      let(:content_structure) { 'simple_image' }
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image1.tif',
                                                  filename: 'image1.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Image 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/3',
                                                  label: 'image2.jp2',
                                                  filename: 'image2.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/4',
                                                  label: 'image2.tif',
                                                  filename: 'image2.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        add_object_files(extension: 'tif')
        add_object_files(extension: 'jp2')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'group by filename structural metadata (image) with file hierarchy' do
      let(:pid) { 'druid:jy812bp9403' }
      let(:cocina_type) { Cocina::Models::ObjectType.image }
      let(:content_structure) { 'simple_image' }
      let(:expected) do
        { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_1',
                       label: 'Image 1',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/1',
                                                  label: '00/image1.tif',
                                                  filename: '00/image1.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: '05/image1.jp2',
                                                  filename: '05/image1.jp2',
                                                  version: 1,
                                                  hasMimeType: 'image/jp2',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } },
                     { type: 'https://cocina.sul.stanford.edu/models/resources/image',
                       externalIdentifier: 'bc234fg5678_2',
                       label: 'Image 2',
                       version: 1,
                       structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/3',
                                                  label: '00/image2.tif',
                                                  filename: '00/image2.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        add_object_files(extension: 'tif', rel_path: '00/')
        add_object_files(num: 1, extension: 'jp2', rel_path: '05/')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'map structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.map }
      let(:content_structure) { 'map' }

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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('map')
        add_object_files(extension: 'jp2')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'book (ltr) structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.book }
      let(:content_structure) { 'simple_book' }

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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [{ members: [], viewingDirection: 'left-to-right' }],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('simple_book')
        add_object_files(extension: 'jp2')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'book structural metadata, with reading order as right-to-left in cocina' do
      let(:cocina_type) { Cocina::Models::ObjectType.book }
      let(:content_structure) { 'simple_book' }
      let(:dro) do
        Cocina::RSpec::Factories.build(:dro, type: cocina_type).new(access: { view: 'world' }, structural: { hasMemberOrders: [{ viewingDirection: 'right-to-left' }] })
      end
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [{ members: [], viewingDirection: 'right-to-left' }],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('simple_book')
        add_object_files(extension: 'jp2')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'webarchive-seed structural metadata' do
      let(:cocina_type) { Cocina::Models::ObjectType.webarchive_seed }
      let(:content_structure) { 'webarchive-seed' }

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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive(:content_structure).and_return('webarchive-seed')
        add_object_files(extension: 'jp2')
      end

      it 'generates the expected structural' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'geo structural metadata' do
      let(:bc) { create(:batch_context, staging_location: 'spec/fixtures/geo') }
      let(:cocina_type) { Cocina::Models::ObjectType.geo }
      let(:content_structure) { 'geo' }

      let(:expected) { { contains: [], hasMemberOrders: [], isMemberOf: [] } }

      before do
        add_object_files(extension: 'zip')
      end

      it 'generates blank structural metadata' do
        expect(object.send(:build_structural).to_h).to eq expected
      end
    end

    describe 'grouped by filename, simple book structural metadata without file attributes' do
      let(:cocina_type) { Cocina::Models::ObjectType.book }
      let(:content_structure) { 'simple_book' }

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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '1111' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/2',
                                                  label: 'image1.tif',
                                                  filename: 'image1.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
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
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } },
                                                { type: 'https://cocina.sul.stanford.edu/models/file',
                                                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/4',
                                                  label: 'image2.tif',
                                                  filename: 'image2.tif',
                                                  version: 1,
                                                  hasMimeType: 'image/tiff',
                                                  sdrGeneratedText: false,
                                                  correctedForAccessibility: false,
                                                  use: nil,
                                                  hasMessageDigests: [{ type: 'md5', digest: '2222' }],
                                                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                  administrative: { publish: false, sdrPreserve: true, shelve: false } }] } }],
          hasMemberOrders: [{ members: [], viewingDirection: 'left-to-right' }],
          isMemberOf: [] }
      end

      before do
        allow(bc).to receive_messages(content_structure: 'simple_book', processing_configuration: 'filename')
        add_object_files(extension: 'tif')
        add_object_files(extension: 'jp2')
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
