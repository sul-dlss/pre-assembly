RSpec.describe DiscoveryReportJob, type: :job do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run) }
  let(:outfile) { 'tmp/foo.out' }

  before { allow(job_run.to_discovery_report).to receive(:output_path).and_return(outfile) }
  after { FileUtils.rm(outfile) if File.exist?(outfile) } # cleanup

  describe '#perform' do
    it 'requires param' do
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end
    it 'writes JSON file and saves job_run.output_location' do
      expect { job.perform(job_run) }.to change { File.exist?(outfile) }.to(true)
      expect(job_run.reload.output_location).to eq(outfile)
    end
  end
end
