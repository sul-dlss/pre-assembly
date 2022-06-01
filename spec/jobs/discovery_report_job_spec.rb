# frozen_string_literal: true

RSpec.describe DiscoveryReportJob, type: :job do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run, :discovery_report) }
  let(:outfile) { 'tmp/foo.out' }

  before { allow(job_run.to_discovery_report).to receive(:output_path).and_return(outfile) }

  after { FileUtils.rm(outfile) if File.exist?(outfile) } # cleanup

  describe '#perform' do
    let(:jbuilder) { instance_double(Jbuilder, target!: '{"x":1}') } # mock the expensive stuff

    before { allow(job_run.to_discovery_report).to receive(:to_builder).and_return(jbuilder) }

    it 'requires param' do
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end

    it 'writes JSON file and saves job_run.output_location' do
      expect { job.perform(job_run) }.to change { File.exist?(outfile) }.to(true)
      expect(job_run.reload.output_location).to eq(outfile)
      expect(job_run).to be_complete
    end
  end
end
