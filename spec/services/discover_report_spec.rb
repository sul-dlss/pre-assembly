require 'rails_helper'

RSpec.describe DiscoveryReport do
  let(:bundle) { bundle_setup_ar_model(:proj_revs) }
  subject(:report) { described_class.new(bundle) }

  before do
    bundle.manifest_rows.each {|row| row.merge!("object" => row["filename"]) }
  end

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
    it 'returns an Enumerable of Hashes' do
      expect(report.each_row).to be_an(Enumerable)
    end
    it 'yields per objects_to_process' do
      expect(report).to receive(:process_dobj).with(1).and_return(fake: 1)
      expect(report).to receive(:process_dobj).with(2).and_return(fake: 2)
      expect(report).to receive(:process_dobj).with(3).and_return(fake: 3)
      expect(bundle).to receive(:objects_to_process).and_return([1, 2, 3])
      report.each_row { |_r| } # no-op
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
        errors: a_hash_including(missing_files: true)
      )
    end
  end
end
