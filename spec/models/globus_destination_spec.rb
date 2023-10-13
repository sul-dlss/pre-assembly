# frozen_string_literal: true

RSpec.describe GlobusDestination do
  subject(:globus_destination) { build(:globus_destination, user:, created_at: timestamp) }

  let(:user) { build(:user, sunet_id: 'ima_user') }
  let(:timestamp) { DateTime.parse('2023-09-21 12:59:59.123') }

  before do
    allow(Settings.globus).to receive_messages(endpoint_id: 'some-endpoint-uuid', directory: '/globus')
  end

  it { is_expected.to belong_to(:user) }

  describe '#directory' do
    it 'gets set automatically' do
      expect(globus_destination.directory).not_to be_nil
      expect(globus_destination.directory).to match(/\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-\d{3}/)
    end
  end

  describe '#url' do
    it 'returns a globus url with the destination path' do
      expect(globus_destination.url).to eq "https://app.globus.org/file-manager?&destination_id=some-endpoint-uuid&destination_path=/ima_user/#{globus_destination.directory}"
    end
  end

  describe '#destination_path' do
    it 'returns the destination globus directory' do
      expect(globus_destination.destination_path).to eq "/ima_user/#{globus_destination.directory}"
    end
  end

  describe '#staging_location' do
    it 'returns the globus staging location' do
      expect(globus_destination.staging_location).to eq "/globus/ima_user/#{globus_destination.directory}"
    end
  end

  describe '#find_with_globus_url' do
    subject(:globus_destination) { build(:globus_destination, user:, directory: '2023-09-21-12-59-59-123') }

    let(:found) { described_class.find_with_globus_url(url) }

    before do
      user.save
      globus_destination.save
    end

    context 'with our globus viewer url' do
      let(:url) { globus_destination.url }

      it 'finds object' do
        expect(found).not_to be_nil
        expect(found.user.sunet_id).to eq('ima_user')
      end
    end

    context 'with the url globus sends in email' do
      let(:url) { 'https://app.globus.org/file-manager?&origin_id=some-endpoint-uuid&origin_path=/ima_user/2023-09-21-12-59-59-123/&add_identity=d28a330f-9d3c-4832-950c-492fb7771a9e' }

      it 'finds object' do
        expect(found).not_to be_nil
      end
    end

    context 'with a emailed globus url after navigation' do
      let(:url) { 'https://app.globus.org/file-manager?&origin_id=some-endpoint-uuid&origin_path=/ima_user/2023-09-21-12-59-59-123/&destination_id=my-laptop&destination_path=/my/dir&add_identity=d28a330f-9d3c-4832-950c-492fb7771a9e' }

      it 'finds object' do
        expect(found).not_to be_nil
      end
    end

    context 'with invalid Globus URL' do
      let(:url) { 'https://example.com' }

      it 'does not find' do
        expect(found).to be_nil
      end
    end
  end

  describe '.stale' do
    let(:stale_destinations) { described_class.find_stale(1.week.ago) }
    let(:active_globus_destination) { create(:globus_destination, user:, created_at: 1.day.ago) }
    let(:stale_globus_destination) { create(:globus_destination, :stale, user:) }

    it 'returns only stale globus_desintation' do
      expect(stale_destinations).to include(stale_globus_destination)
      expect(stale_destinations).not_to include(active_globus_destination)
    end
  end
end
