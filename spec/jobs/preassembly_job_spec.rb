# frozen_string_literal: true

RSpec.describe PreassemblyJob, type: :job do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run, :preassembly) }
  let(:outfile) { 'tmp/foobar_progress.yaml' }

  before { allow(job_run.batch_context).to receive(:progress_log_file).and_return(outfile) }

  after { FileUtils.rm(outfile) if File.exist?(outfile) } # cleanup

  describe '#perform' do
    it 'requires param' do
      allow(job_run.batch_context.batch).to receive(:process_digital_objects) # not testing actual work here
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end

    context 'when success' do
      before { allow(job_run.batch_context.batch).to receive(:run_pre_assembly).and_return(true) }

      it 'calls run_pre_assembly and ends in an complete state' do
        job.perform(job_run)
        expect(job_run).to be_complete
      end
    end

    context 'when errors' do
      before { allow(job_run.batch_context.batch).to receive(:run_pre_assembly).and_return(false) }

      it 'calls run_pre_assembly and ends in a completed with error state' do
        job.perform(job_run)
        expect(job_run).to be_complete_with_errors
      end
    end
  end
end
