# frozen_string_literal: true

RSpec.describe DiscoveryReport do
  subject(:report) { described_class.new(batch) }

  let(:batch) { batch_setup(:flat_dir_images) }

  before do
    # make sure that for these tests
    # (a) the tmp job output dir exists for the progress log file to be written to
    # (b) we get a new clean progress log file for the tests each time we run them
    # In the actual application, `batch_context.output_dir_no_exists!` would get run and thus we would always have a unique folder created for each job
    FileUtils.mkdir_p(batch.batch_context.output_dir)
    FileUtils.rm_f(batch.batch_context.progress_log_file)
  end

  describe '#initialize' do
    it 'raises if PreAssembly::Batch not received' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end

    it 'accepts PreAssembly::Batch' do
      expect { described_class.new(batch) }.not_to raise_error
    end
  end

  describe '#each_row' do
    # rubocop:disable RSpec/IndexedLet
    let(:druid1) { DruidTools::Druid.new('cb837cp4412') }
    let(:druid2) { DruidTools::Druid.new('cm057cr1745') }
    let(:druid3) { DruidTools::Druid.new('cp898cs9946') }
    let(:results1) { { errors: {}, counts:  { total_size: 1, mimetypes: { a: 1, b: 2 } } } }
    let(:results2) { { errors: {}, counts:  { total_size: 2, mimetypes: { b: 3, q: 4 } } } }
    let(:results3) { { errors: { foo: true }, counts: { total_size: 3, mimetypes: { q: 9 } } } }
    let(:validator1) { instance_double(ObjectFileValidator, counts: results1[:counts], errors: results1[:errors], to_h: results1) }
    let(:validator2) { instance_double(ObjectFileValidator, counts: results2[:counts], errors: results2[:errors], to_h: results2) }
    let(:validator3) { instance_double(ObjectFileValidator, counts: results3[:counts], errors: results3[:errors], to_h: results3) }
    let(:cocina_obj1) { Cocina::RSpec::Factories.build(:dro, id: druid1.druid) }
    let(:cocina_obj2) { Cocina::RSpec::Factories.build(:dro, id: druid2.druid) }
    let(:cocina_obj3) { Cocina::RSpec::Factories.build(:dro, id: druid3.druid) }

    let(:dig_obj1) do
      instance_double(PreAssembly::DigitalObject, druid: druid1, build_structural: cocina_obj1.structural, existing_cocina_object: cocina_obj1, staging_location: '', current_object_version: 2)
    end
    let(:dig_obj2) do
      instance_double(PreAssembly::DigitalObject, druid: druid2, build_structural: cocina_obj2.structural, existing_cocina_object: cocina_obj2, staging_location: '', current_object_version: 2)
    end
    let(:dig_obj3) do
      instance_double(PreAssembly::DigitalObject, druid: druid3, build_structural: cocina_obj3.structural, existing_cocina_object: cocina_obj3, staging_location: '', current_object_version: 2)
    end
    # rubocop:enable RSpec/IndexedLet

    it 'returns an Enumerable of Hashes' do
      expect(report.send(:each_row)).to be_an(Enumerable)
    end

    it 'yields per un_pre_assembled_objects, building an aggregate summary and logging status per druid' do
      expect(report).to receive(:process_dobj).with(dig_obj1).and_return(validator1)
      expect(report).to receive(:process_dobj).with(dig_obj2).and_return(validator2)
      expect(report).to receive(:process_dobj).with(dig_obj3).and_return(validator3)
      expect(batch).to receive(:un_pre_assembled_objects).and_return([dig_obj1, dig_obj2, dig_obj3].to_enum)
      report.send(:each_row) { |r| expect(r).to be_a Hash } # iterate through the Enumerable that generates the report
      expect(report.summary).to match a_hash_including(
        total_size: 6,
        objects_with_error: ['cp898cs9946'],
        mimetypes: { a: 1, b: 5, q: 13 }
      )
      expect(File).to exist(batch.batch_context.progress_log_file)
      docs = YAML.load_stream(File.read(batch.batch_context.progress_log_file))
      expect(docs.size).to eq(3)
      expect(docs[0]).to include(pid: 'cb837cp4412', status: 'success')
      expect(docs[0][:timestamp].to_date).to eq Time.now.utc.to_date
      expect(docs[1]).to include(pid: 'cm057cr1745', status: 'success')
      expect(docs[2]).to include(pid: 'cp898cs9946', status: 'error')
    end
  end

  describe '#output_path' do
    it 'starts with output_dir' do
      expect(report.output_path).to start_with(report.batch.batch_context.output_dir)
    end

    it 'ends with discovery_report[...].json' do
      expect(report.output_path).to match(/discovery_report_.*\.json$/)
    end

    it 'gives unique string each invocation' do
      expect(report.output_path).not_to eq(report.output_path)
    end
  end

  context 'integration test' do
    let(:bc_params) do
      {
        project_name: 'SmokeTest',
        content_structure:,
        staging_location: 'spec/fixtures/images_jp2_tif',
        staging_style_symlink: false,
        processing_configuration: 0,
        user: build(:user, sunet_id: 'jdoe')
      }
    end
    let(:batch_context) { BatchContext.new(bc_params) }
    let(:job_run) { JobRun.new(batch_context:) }
    let(:batch) { PreAssembly::Batch.new(job_run) }
    let(:dobj) { report.batch.un_pre_assembled_objects.first }
    let(:item) do
      Cocina::RSpec::Factories.build(:dro).new(access: { view: 'world' }, structural:)
    end
    let(:structural) { { contains: [] } }
    let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true, status:) }
    let(:status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, version:) }
    let(:version) { 2 }
    let(:client_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(client_object)
    end

    context 'with image content structure type' do
      let(:content_structure) { 'simple_image' }

      it 'to_builder gives expected output for one dobj' do
        report_json = JSON.parse(report.to_builder.target!)
        expect(report_json['rows'].first.with_indifferent_access).to match(
          druid: 'druid:jy812bp9403',
          errors: {
            wrong_content_structure: true
          },
          counts: {
            total_size: 127_401,
            mimetypes: { 'image/tiff' => 2, 'image/jp2' => 1 },
            filename_no_extension: 0
          },
          file_diffs: {
            added_files: [
              '00/image1.tif',
              '00/image2.tif',
              '05/image1.jp2'
            ],
            deleted_files: [],
            updated_files: []
          }
        )
      end

      it 'produces the json, indicates errors occurred' do
        json = JSON.parse(report.to_builder.target!)
        expect(json['rows'].size).to eq 3
        expect(report.objects_had_errors?).to be true
        expect(report.error_message).to eq '2 objects had errors in the discovery report' # hierarchy with non-file type
        expect(report.summary).to include(objects_with_error: %w[jy812bp9403 tz250tk7584], total_size: 382_224)
      end
    end

    context 'when first version and no files' do
      let(:content_structure) { 'simple_image' }
      let(:version) { 1 }

      it 'to_builder excludes file diff' do
        report_json = JSON.parse(report.to_builder.target!)
        expect(report_json['rows'].first.key?('file_diffs')).to be false
      end
    end

    context 'when first version and has files' do
      let(:content_structure) { 'simple_image' }
      let(:version) { 1 }
      let(:structural) do
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
                                                  administrative: { publish: true, sdrPreserve: false, shelve: true } }] } }],
          hasMemberOrders: [],
          isMemberOf: [] }
      end

      it 'to_builder excludes file diff' do
        report_json = JSON.parse(report.to_builder.target!)
        expect(report_json['rows'].first.key?('file_diffs')).to be true
      end
    end

    context 'with file content structure type' do
      let(:content_structure) { 'file' }

      it 'process_dobj gives expected output for one dobj' do
        expect(report.send(:process_dobj, dobj).as_json).to eq(
          druid: 'druid:jy812bp9403',
          errors: {},
          counts: {
            total_size: 127_401,
            mimetypes: { 'image/tiff' => 2, 'image/jp2' => 1 },
            filename_no_extension: 0
          }
        )
      end

      it 'produces the json, indicates no errors occurred' do
        json = JSON.parse(report.to_builder.target!)
        expect(json['rows'].size).to eq 3
        expect(report.objects_had_errors?).to be false
        expect(report.error_message).to be_nil
        expect(report.summary).to include(objects_with_error: [], total_size: 382_224)
      end
    end

    context 'with item that is not registered' do
      let(:content_structure) { 'simple_image' }

      before do
        allow(client_object).to receive(:find).and_raise(RuntimeError)
      end

      it 'to_builder gives expected output for one dobj omitting structural diff' do
        report_json = JSON.parse(report.to_builder.target!)
        expect(report_json['rows'].first.with_indifferent_access).to match(
          druid: 'druid:jy812bp9403',
          errors: {
            wrong_content_structure: true,
            dor_connection_error: true
          },
          counts: {
            total_size: 127_401,
            mimetypes: { 'image/tiff' => 2, 'image/jp2' => 1 },
            filename_no_extension: 0
          }
        )
      end
    end
  end
end
