# frozen_string_literal: true

RSpec.describe PreassemblyJob, type: :job do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run, :preassembly) }
  let(:outfile) { 'tmp/foobar_progress.yaml' }
  let(:batch_context) { job_run.batch_context }

  before do
    allow(batch_context).to receive(:progress_log_file).and_return(outfile)
    allow(batch_context.batch).to receive(:process_digital_objects)
  end

  after { FileUtils.rm(outfile) if File.exist?(outfile) } # cleanup

  describe '#perform' do
    it 'requires param' do
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end

    context 'when success' do
      before { allow(batch_context.batch).to receive(:had_errors).and_return(false) }

      it 'calls run_pre_assembly and ends in an complete state' do
        job.perform(job_run)
        expect(job_run).to be_complete
        expect(job_run.error_message).to be_nil
      end
    end

    context 'when errors' do
      let(:error_message) { 'something bad happened' }

      before do
        allow(batch_context.batch).to receive(:had_errors).and_return(true)
        allow(batch_context.batch).to receive(:error_message).and_return(error_message)
      end

      it 'calls run_pre_assembly and ends in a completed with error state, and saves error message to the database' do
        job.perform(job_run)
        expect(job_run).to be_complete_with_errors
        expect(job_run.error_message).to eq error_message
      end
    end
  end
end
