# frozen_string_literal: true

RSpec.describe GlobusDestination do
  subject(:globus_destination) { build(:globus_destination, user:, created_at: timestamp) }

  let(:user) { build(:user, sunet_id: 'ima_user') }
  let(:timestamp) { DateTime.new(2023, 9, 21, 12, 59, 59) }

  before do
    allow(Settings.globus).to receive_messages(endpoint_id: 'some-endpoint-uuid', directory: '/globus')
  end

  it { is_expected.to belong_to(:user) }

  describe '#url' do
    it 'returns a globus url with the destination path' do
      expect(globus_destination.url).to eq 'https://app.globus.org/file-manager?&destination_id=some-endpoint-uuid&destination_path=/ima_user/20230921125959'
    end
  end

  describe '#destination_path' do
    it 'returns the destination globus directory' do
      expect(globus_destination.destination_path).to eq '/ima_user/20230921125959'
    end
  end

  describe '#staging_location' do
    it 'returns the globus staging location' do
      expect(globus_destination.staging_location).to eq '/globus/ima_user/20230921125959'
    end
  end

  describe '#parse_path' do
    let(:url) { 'https://app.globus.org/file-manager?&destination_id=some-endpoint-uuid&destination_path=/ima_user/20230921125959' }

    it 'finds the destination_path' do
      expect(globus_destination.parse_path(url)).to eq '/ima_user/20230921125959'
    end
  end
end
