# frozen_string_literal: true

RSpec.describe AccessionCompleteJob do
  subject(:run) { described_class.new.work(message) }

  let(:message) do
    {
      druid:,
      version:,
      note: nil,
      lifecycle: nil,
      laneId: 'default',
      elapsed: nil,
      attempts: 0,
      datetime: Time.now.iso8601,
      status:,
      name: 'end-accession',
      action: 'workflow updated'
    }.to_json
  end

  let(:druid) { 'druid:bb123bc1234' }
  let(:bare_druid) { 'bb123bc1234' }
  let(:version) { 1 }

  before do
    allow(JobRunCompleteJob).to receive(:perform_later)
  end

  context 'when a completed message' do
    let(:status) { 'completed' }

    context 'when an accession' do
      let!(:accession_in_progress) { create(:accession, druid: bare_druid, version:, state: 'in_progress') }
      let!(:accession_failed) { create(:accession, druid: bare_druid, version:, state: 'failed') }
      let!(:accession_different_version) { create(:accession, druid: bare_druid, version: version + 1, state: 'in_progress') }
      let!(:accession_completed) { create(:accession, druid: bare_druid, version:, state: 'completed') }

      it 'updates the accessions and acks' do
        expect(run).to eq(:ack)
        expect(accession_in_progress.reload.state).to eq('completed')
        expect(accession_failed.reload.state).to eq('completed')
        expect(accession_different_version.reload.state).to eq('in_progress')
        expect(accession_completed.reload.state).to eq('completed')
      end
    end

    context 'when no accessions' do
      it 'acks' do
        expect(run).to eq(:ack)
        expect(JobRunCompleteJob).not_to have_received(:perform_later)
      end
    end
  end

  context 'when an error message' do
    let(:status) { 'error' }

    context 'when an accession' do
      let!(:accession_in_progress) { create(:accession, druid: bare_druid, version:, state: 'in_progress') }
      let!(:accession_failed) { create(:accession, druid: bare_druid, version:, state: 'failed') }
      let!(:accession_different_version) { create(:accession, druid: bare_druid, version: version + 1, state: 'in_progress') }
      let!(:accession_completed) { create(:accession, druid: bare_druid, version:, state: 'completed') }

      it 'updates the accessions and acks' do
        expect(run).to eq(:ack)
        expect(accession_in_progress.reload.state).to eq('failed')
        expect(accession_failed.reload.state).to eq('failed')
        expect(accession_different_version.reload.state).to eq('in_progress')
        expect(accession_completed.reload.state).to eq('completed')
      end
    end

    context 'when no accessions' do
      it 'acks' do
        expect(run).to eq(:ack)
        expect(JobRunCompleteJob).not_to have_received(:perform_later)
      end
    end
  end

  context 'when an unknown message' do
    let(:status) { 'started' }

    it 'raises' do
      expect { run }.to raise_error(StandardError, /Unexpected message status/)
    end
  end
end
