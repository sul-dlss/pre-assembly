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
    let(:dig_obj1) { instance_double(PreAssembly::DigitalObject, druid: druid1) }
    let(:dig_obj2) { instance_double(PreAssembly::DigitalObject, druid: druid2) }
    let(:dig_obj3) { instance_double(PreAssembly::DigitalObject, druid: druid3) }
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
        objects_with_error: 1,
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
        content_metadata_creation: 0,
        user: build(:user, sunet_id: 'jdoe')
      }
    end
    let(:batch_context) { BatchContext.new(bc_params) }
    let(:batch) { PreAssembly::Batch.new(batch_context) }
    let(:dobj) { report.batch.un_pre_assembled_objects.first }
    let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
    let(:item) { instance_double(Cocina::Models::DRO, access: cocina_model_world_access) }
    let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true) }
    let(:client_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(client_object)
    end

    context 'with image content structure type' do
      let(:content_structure) { 'simple_image' }

      it 'process_dobj gives expected output for one dobj' do
        expect(report.send(:process_dobj, dobj).as_json).to eq(
          druid: 'druid:jy812bp9403',
          errors: {
            wrong_content_structure: true
          },
          counts: {
            total_size: 127_401,
            mimetypes: { 'image/tiff' => 2, 'image/jp2' => 1 },
            filename_no_extension: 0
          }
        )
      end

      it 'produces the json, indicates errors occurred' do
        json = JSON.parse(report.to_builder.target!)
        expect(json['rows'].size).to eq 3
        expect(report.objects_had_errors).to be true
        expect(report.error_message).to eq '2 objects had errors in the discovery report' # hierarchy with non-file type
        expect(report.summary).to include(objects_with_error: 2, total_size: 382_224)
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
        expect(report.objects_had_errors).to be false
        expect(report.error_message).to be_nil
        expect(report.summary).to include(objects_with_error: 0, total_size: 382_224)
      end
    end
  end
end
