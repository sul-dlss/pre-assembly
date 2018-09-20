require 'rails_helper'

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
      let(:obj_file) { instance_double(PreAssembly::ObjectFile, path: "random/path", filesize: 324, mimetype: "")}

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
end
