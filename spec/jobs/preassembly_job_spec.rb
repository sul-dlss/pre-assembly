# frozen_string_literal: true

RSpec.describe PreassemblyJob do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run, :preassembly) }
  let(:outfile) { 'tmp/foobar_progress.yaml' }
  let(:batch_context) { job_run.batch_context }
  let(:batch) { job_run.batch }

  before do
    allow(batch_context).to receive(:progress_log_file).and_return(outfile)
    allow(batch).to receive(:pre_assemble_objects)
    allow(JobRunCompleteJob).to receive(:perform_later)
  end

  after { FileUtils.rm_rf(outfile) } # cleanup

  describe '#perform' do
    it 'requires param' do
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end

    context 'when success' do
      before { allow(batch).to receive(:objects_had_errors).and_return(false) }

      it 'calls run_pre_assembly and ends in an complete state' do
        expect(batch).to receive(:run_pre_assembly)
        job.perform(job_run)
        expect(job_run).to be_preassembly_complete
        expect(job_run.error_message).to be_nil
        expect(JobRunCompleteJob).to have_received(:perform_later).with(job_run)
      end
    end

    context 'when failed' do
      let(:error_message) { 'StandardError : something really unexpected happened' }
      # simulate an uncaught exception while running the job

      before { allow(batch).to receive(:pre_assemble_objects).and_raise(StandardError, error_message) }

      it 'ends in a failed state with an uncaught exception, and saves error message to the database' do
        job.perform(job_run)
        expect(job_run).to be_failed
        expect(job_run.error_message).to eq error_message
      end
    end

    context 'when errors' do
      let(:error_message) { 'something bad happened' }

      before do
        allow(batch).to receive_messages(objects_had_errors: true, error_message:)
      end

      it 'calls run_pre_assembly and ends in a completed with error state, and saves error message to the database' do
        expect(batch).to receive(:run_pre_assembly)
        job.perform(job_run)
        expect(job_run).to be_preassembly_complete_with_errors
        expect(job_run.error_message).to eq error_message
        expect(JobRunCompleteJob).to have_received(:perform_later).with(job_run)
      end
    end
  end
end
