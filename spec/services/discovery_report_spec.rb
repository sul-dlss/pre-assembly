# frozen_string_literal: true

RSpec.describe DiscoveryReport do
  subject(:report) { described_class.new(bundle) }

  let(:bundle) { bundle_setup(:flat_dir_images) }

  describe '#initialize' do
    it 'raises if PreAssembly::Bundle not received' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end
    it 'accepts PreAssembly::Bundle' do
      expect { described_class.new(bundle) }.not_to raise_error
    end
  end

  describe '#each_row' do
    let(:validator1) { instance_double(ObjectFileValidator, counts: { total_size: 1, mimetypes: { a: 1, b: 2 } }, errors: {}) }
    let(:validator2) { instance_double(ObjectFileValidator, counts: { total_size: 2, mimetypes: { b: 3, q: 4 } }, errors: {}) }
    let(:validator3) { instance_double(ObjectFileValidator, counts: { total_size: 3, mimetypes: { q: 9 } }, errors: { foo: true }) }

    it 'returns an Enumerable of Hashes' do
      expect(report.each_row).to be_an(Enumerable)
    end
    it 'yields per objects_to_process, building an aggregate summary' do
      expect(report).to receive(:process_dobj).with(1).and_return(validator1)
      expect(report).to receive(:process_dobj).with(2).and_return(validator2)
      expect(report).to receive(:process_dobj).with(3).and_return(validator3)
      expect(bundle).to receive(:objects_to_process).and_return([1, 2, 3])
      report.each_row { |_r| } # no-op
      expect(report.summary).to match a_hash_including(
        total_size: 6,
        objects_with_error: 1,
        mimetypes: { a: 1, b: 5, q: 13 }
      )
    end
  end

  describe '#output_path' do
    it 'starts with output_dir' do
      expect(report.output_path).to start_with(report.bundle.bundle_context.output_dir)
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
        content_structure: 0,
        bundle_dir: 'spec/test_data/images_jp2_tif',
        staging_style_symlink: false,
        content_metadata_creation: 0,
        user: build(:user, sunet_id: 'jdoe')
      }
    end
    let(:bundle_context) { BundleContext.new(bc_params) }
    let(:bundle) { PreAssembly::Bundle.new(bundle_context) }
    let(:dobj) { report.bundle.objects_to_process.first }
    let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, access: 'world') }
    let(:item) { instance_double(Cocina::Models::DRO, access: cocina_model_world_access) }
    let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, open: true, close: true) }
    let(:client_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(client_object)
    end

    it 'process_dobj gives expected output for one dobj' do
      allow(dobj).to receive(:pid).and_return('kk203bw3276')
      expect(report.process_dobj(dobj).as_json).to eq(
        druid: 'druid:kk203bw3276',
        errors: { dupes: true },
        counts: {
          total_size: 254_802,
          mimetypes: { 'image/tiff' => 4, 'image/jp2' => 2 },
          filename_no_extension: 0
        }
      )
      expect(report.summary).to include(
        objects_with_error: 0, mimetypes: {}, total_size: 0
      )
    end
  end
end
