# frozen_string_literal: true

RSpec.describe GlobusCleanup do
  let(:user) { create(:user, sunet_id: 'ima_user') }

  let!(:job_run) { create(:job_run, :preassembly) }
  let!(:job_run_complete) { create(:job_run, :preassembly, :accessioning_complete) }

  describe '.run' do
    before do
      allow(described_class).to receive(:cleanup_destination)
      create(:globus_destination, user:, batch_context: job_run.batch_context, created_at: 1.day.ago)
      create(:globus_destination, user:, batch_context: job_run.batch_context, created_at: 1.month.ago)
    end

    context 'when no complete accessioning jobs' do
      before { create(:globus_destination, :stale, user:, batch_context: job_run.batch_context) }

      it 'does not delete any globus destinations' do
        described_class.run
        expect(described_class).not_to have_received(:cleanup_destination)
      end
    end

    context 'when one complete accessioning job' do
      let!(:stale_globus_destination) { create(:globus_destination, :stale, user:, batch_context: job_run_complete.batch_context) }

      it 'deletes stale globus destination' do
        described_class.run
        expect(described_class).to have_received(:cleanup_destination).once.with(stale_globus_destination)
      end
    end
  end

  describe '.cleanup_destination' do
    let(:stale_globus_destination) { create(:globus_destination, :stale, user:, batch_context: job_run.batch_context) }

    before { allow(GlobusClient).to receive(:delete_access_rule) }

    it 'marks destination as deleted and deletes access rule' do
      expect(stale_globus_destination.deleted_at).to be_nil
      described_class.cleanup_destination(stale_globus_destination)
      expect(GlobusClient).to have_received(:delete_access_rule).once
      expect(stale_globus_destination.deleted_at).not_to be_nil
    end
  end
end
