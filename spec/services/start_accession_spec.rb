# frozen_string_literal: true

RSpec.describe StartAccession do
  describe '.run' do
    subject(:start_accession) { described_class.run(druid: pid, user: user.sunet_id) }

    let(:user) { create(:user) }
    let(:pid) { 'druid:gn330dv6119' }
    let(:accession_object) { instance_double(Dor::Services::Client::Accession, start: true) }
    let(:object_client) { instance_double(Dor::Services::Client::Object, accession: accession_object) }

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(object_client)
    end

    context 'when api client is successful' do
      it 'starts accession' do
        start_accession
        expect(object_client.accession).to have_received(:start).with(
          significance: 'major',
          description: 'pre-assembly re-accession',
          opening_user_name: user.sunet_id
        )
      end
    end

    context 'when the api client raises' do
      before do
        allow(object_client).to receive(:accession).and_raise(StandardError)
      end

      it 'raises an exception' do
        expect { start_accession }.to raise_error(StandardError)
      end
    end
  end
end
