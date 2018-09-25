RSpec.describe PreassemblyJob, type: :job do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run) }
  let(:outfile) { 'tmp/foobar_progress.yaml' }

  before { allow(job_run.bundle_context).to receive(:progress_log_file).and_return(outfile) }
  after { FileUtils.rm(outfile) if File.exist?(outfile) } # cleanup

  describe '#perform' do
    it 'requires param' do
      allow(job_run.bundle_context.bundle).to receive(:process_digital_objects) # not testing actual work here
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end
    it 'calls run_pre_assembly and saves job_run.output_location' do
      expect(job_run.bundle_context.bundle).to receive(:run_pre_assembly)
      job.perform(job_run)
      expect(job_run.reload.output_location).to eq(outfile)
    end
  end
end
