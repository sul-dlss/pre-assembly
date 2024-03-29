# frozen_string_literal: true

RSpec.describe DiscoveryReportJob do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run) }
  let(:outfile) { 'tmp/foo.out' }

  before { allow(job_run.to_discovery_report).to receive(:output_path).and_return(outfile) }

  after { FileUtils.rm_rf(outfile) } # cleanup

  describe '#perform' do
    let(:jbuilder) { instance_double(Jbuilder, target!: '{"x":1}') } # mock the expensive stuff

    before { allow(job_run.to_discovery_report).to receive(:to_builder).and_return(jbuilder) }

    it 'requires param' do
      expect { job.perform }.to raise_error(ArgumentError)
      expect { job.perform(job_run) }.not_to raise_error
    end

    context 'when success' do
      it 'writes JSON file and saves job_run.output_location' do
        expect { job.perform(job_run) }.to change { File.exist?(outfile) }.to(true)
        expect(job_run.reload.output_location).to eq(outfile)
        expect(job_run).to be_discovery_report_complete
        expect(job_run.with_preassembly_errors?).to be false
      end
    end

    context 'when failed' do
      let(:error_message) { 'StandardError : something really unexpected happened' }
      # simulate an uncaught exception while running the job

      before { allow(job_run.to_discovery_report).to receive(:to_builder).and_raise(StandardError, error_message) }

      it 'ends in a failed state with an uncaught exception, and saves error message to the database' do
        job.perform(job_run)
        expect(job_run).to be_failed
        expect(job_run.error_message).to eq error_message
        expect(job_run.with_preassembly_errors?).to be true
      end
    end

    context 'when errors' do
      let(:error_message) { 'something bad happened' }

      before do
        allow(job_run.to_discovery_report).to receive_messages(objects_had_errors?: true, error_message:)
      end

      it 'calls to_discovery_report and ends in a completed with error state, and saves error message to the database' do
        job.perform(job_run)
        expect(job_run).to be_discovery_report_complete
        expect(job_run.error_message).to eq error_message
        expect(job_run.with_preassembly_errors?).to be true
      end
    end
  end
end
