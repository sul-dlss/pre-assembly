RSpec.describe DiscoveryReport do
  let(:bundle) { bundle_setup(:flat_dir_images) }
  subject(:report) { described_class.new(bundle) }

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
    let(:dobj_hash1) { { druid: '1', counts: { total_size: 1, mimetypes: { a: 1, b: 2 } }, errors: {} } }
    let(:dobj_hash2) { { druid: '2', counts: { total_size: 2, mimetypes: { b: 3, q: 4 } }, errors: {} } }
    let(:dobj_hash3) { { druid: '3', counts: { total_size: 3, mimetypes: { q: 9 } }, errors: { foo: true } } }

    it 'returns an Enumerable of Hashes' do
      expect(report.each_row).to be_an(Enumerable)
    end
    it 'yields per objects_to_process, building an aggregate summary' do
      expect(report).to receive(:process_dobj).with(1).and_return(dobj_hash1)
      expect(report).to receive(:process_dobj).with(2).and_return(dobj_hash2)
      expect(report).to receive(:process_dobj).with(3).and_return(dobj_hash3)
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

  describe '#process_dobj' do
    let(:dobj) { report.bundle.objects_to_process.first }

    before do
      allow(dobj).to receive(:pid).and_return('kk203bw3276')
      allow(report).to receive(:registration_check).and_return({}) # pretend everything is in Dor
    end

    it 'converts a DigtialObject to structured data (Hash)' do
      expect(report.process_dobj(dobj)).to match a_hash_including(
        counts: a_hash_including(total_size: 0),
        errors: a_hash_including(missing_files: true),
        druid: 'druid:kk203bw3276'
      )
    end

    context "folders are empty" do
      it "adds empty_object error" do
        expect(report.process_dobj(dobj)).to match a_hash_including(errors: a_hash_including(empty_object: true))
      end
    end

    context "folders are not empty" do
      let(:obj_file) { instance_double(PreAssembly::ObjectFile, path: "random/path", filesize: 324, mimetype: "") }

      before do
        allow(dobj).to receive(:object_files).and_return([obj_file, obj_file])
        allow(report).to receive(:using_smpl_manifest?).and_return(false)
        allow(report).to receive(:registration_check).and_return({}) # pretend everything is in Dor
      end

      it "does not add empty_object error" do
        expect(report.process_dobj(dobj)).not_to include(a_hash_including(empty_object: true))
      end
    end
  end

  context "integration test" do
    let(:bc_params) do
      {
        project_name: "SmokeTest",
        content_structure: 0,
        bundle_dir: 'spec/test_data/images_jp2_tif',
        staging_style_symlink: false,
        content_metadata_creation: 0,
        user: build(:user, sunet_id: 'jdoe@stanford.edu')
      }
    end
    let(:bundle_context) { BundleContext.new(bc_params) }
    let(:bundle) { PreAssembly::Bundle.new(bundle_context) }
    let(:dobj) { report.bundle.objects_to_process.first }

    before do
      allow(dobj).to receive(:pid).and_return("kk203bw3276")
      allow(report).to receive(:registration_check).and_return({}) # pretend everything is in Dor
    end

    it 'process_dobj gives expected output for one dobj' do
      expect(report.process_dobj(dobj)).to eq(
        druid: "druid:kk203bw3276",
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
