require 'rails_helper'

RSpec.describe DiscoveryReport do
  let(:bundle) { bundle_setup(:proj_revs) }
  subject(:report) { described_class.new(bundle) }

  before do
    allow_any_instance_of(BundleContext).to receive(:validate_usage) # to be replaced w/ AR validation
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
end
