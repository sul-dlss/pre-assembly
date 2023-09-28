# frozen_string_literal: true

RSpec.describe GlobusDestination do
  subject(:globus_destination) { build(:globus_destination, user:, created_at: timestamp) }

  let(:user) { build(:user, sunet_id: 'ima_user') }
  let(:timestamp) { DateTime.parse('2023-09-21 12:59:59.123') }

  before do
    allow(Settings.globus).to receive_messages(endpoint_id: 'some-endpoint-uuid', directory: '/globus')
  end

  it { is_expected.to belong_to(:user) }

  describe '#timestamp' do
    it 'persists with microseconds' do
      expect(globus_destination.created_at.strftime('%L')).to eq '123'
    end
  end

  describe '#url' do
    it 'returns a globus url with the destination path' do
      expect(globus_destination.url).to eq 'https://app.globus.org/file-manager?&destination_id=some-endpoint-uuid&destination_path=/ima_user/2023-09-21-12-59-59-123'
    end
  end

  describe '#destination_path' do
    it 'returns the destination globus directory' do
      expect(globus_destination.destination_path).to eq '/ima_user/2023-09-21-12-59-59-123'
    end
  end

  describe '#staging_location' do
    it 'returns the globus staging location' do
      expect(globus_destination.staging_location).to eq '/globus/ima_user/2023-09-21-12-59-59-123'
    end
  end

  describe '#find_with_globus_url' do
    let(:url) { 'https://app.globus.org/file-manager?&destination_id=some-endpoint-uuid&destination_path=/ima_user/2023-09-21-12-59-59-123' }

    before do
      user.save
      globus_destination.save
    end

    it 'finds object' do
      globus_dest = described_class.find_with_globus_url(url)
      expect(globus_dest).not_to be_nil
      expect(globus_dest.user.sunet_id).to eq('ima_user')
    end

    it 'does not find' do
      expect(described_class.find_with_globus_url('http://example.com')).to be_nil
    end
  end
end
