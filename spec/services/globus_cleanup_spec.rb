# frozen_string_literal: true

RSpec.describe GlobusCleanup do
  let(:user) { create(:user, sunet_id: 'ima_user') }

  let!(:job_run) { create(:job_run, :preassembly) }
  let!(:job_run_complete) { create(:job_run, :preassembly, :accessioning_complete) }

  describe '.run' do
    before do
      allow(described_class).to receive(:cleanup_stale_completed)
      allow(described_class).to receive(:cleanup_stale_unused)
    end

    it 'calls both cleanup methods' do
      described_class.run
      expect(described_class).to have_received(:cleanup_stale_completed)
      expect(described_class).to have_received(:cleanup_stale_unused)
    end
  end

  describe '.cleanup_stale_completed' do
    before { allow(described_class).to receive(:cleanup_destination) }

    context 'when no complete accessioning jobs' do
      before { create(:globus_destination, :stale, user:, batch_context: job_run.batch_context) }

      it 'does not delete any globus destinations' do
        described_class.cleanup_stale_completed
        expect(described_class).not_to have_received(:cleanup_destination)
      end
    end

    context 'when one complete accessioning job more than 1 week old' do
      let!(:stale_globus_destination) { create(:globus_destination, :stale, user:, batch_context: job_run_complete.batch_context) }

      it 'deletes stale globus destination' do
        described_class.cleanup_stale_completed
        expect(described_class).to have_received(:cleanup_destination).once.with(stale_globus_destination)
      end
    end
  end

  describe '.cleanup_stale_unused' do
    before { allow(described_class).to receive(:cleanup_destination) }

    context 'when no unused globus destination' do
      before { create(:globus_destination, :stale, user:, batch_context: job_run.batch_context) }

      it 'does not delete any globus destinations' do
        described_class.cleanup_stale_unused
        expect(described_class).not_to have_received(:cleanup_destination)
      end
    end

    context 'when a destination with no associated batch_context more than 1 month old' do
      let!(:disconnected_stale_globus_destination) { create(:globus_destination, :stale, user:, batch_context: nil) }

      it 'deletes stale globus destination' do
        described_class.cleanup_stale_unused
        expect(described_class).to have_received(:cleanup_destination).once.with(disconnected_stale_globus_destination)
      end
    end
  end

  describe '.cleanup_destination' do
    let(:stale_globus_destination) { create(:globus_destination, :stale, user:, batch_context: job_run.batch_context) }

    context 'when GlobusClient returns a response' do
      before { allow(GlobusClient).to receive(:delete_access_rule) }

      it 'marks destination as deleted and deletes access rule' do
        expect(stale_globus_destination.deleted_at).to be_nil
        described_class.cleanup_destination(stale_globus_destination)
        expect(GlobusClient).to have_received(:delete_access_rule).once
        expect(stale_globus_destination.deleted_at).not_to be_nil
      end
    end

    context 'when GlobusClient throws an error' do
      before do
        allow(GlobusClient).to receive(:delete_access_rule).and_raise(StandardError)
        allow(Honeybadger).to receive(:notify)
      end

      it 'notifies honeybadger' do
        described_class.cleanup_destination(stale_globus_destination)
        expect(Honeybadger).to have_received(:notify).with(StandardError,
                                                           context: { message: 'GlobusCleanup failed',
                                                                      globus_destination_id: stale_globus_destination.id })
      end
    end
  end
end
