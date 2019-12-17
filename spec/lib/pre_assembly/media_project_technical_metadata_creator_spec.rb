# frozen_string_literal: true

RSpec.describe PreAssembly::MediaProjectTechnicalMetadataCreator do
  subject(:creator) do
    described_class.new(pid: "druid:#{druid}",
                        bundle_dir: bundle_dir,
                        container: druid)
  end

  let(:bundle_dir) { Rails.root.join('spec/test_data/multimedia') }
  let(:druid) { 'aa111aa1111' }

  describe '#create_content_metadata - no thumb declaration' do
    subject(:exp_xml) { noko_doc(creator.create) }

    it 'generates technicalMetadata for Media by combining all existing _techmd.xml files' do
      expect(exp_xml.css('technicalMetadata').size).to eq(1) # one top level node
      expect(exp_xml.css('Mediainfo').size).to eq(2) # two Mediainfo nodes
      counts = exp_xml.css('Count')
      expect(counts.size).to eq(4) # four nodes that have file info
      # look for some specific bits in the files that have been assembled
      expect(counts.map(&:content)).to eq(%w[279 217 280 218])
    end
  end

  describe '#container_basename' do
    subject(:creator) do
      described_class.new(pid: "druid:#{druid}",
                          bundle_dir: bundle_dir,
                          container: "foo/bar/#{druid}")
    end

    let(:druid) { 'xx111yy2222' }

    it 'returns expected value' do
      expect(creator.send(:container_basename)).to eq(druid)
    end
  end
end
