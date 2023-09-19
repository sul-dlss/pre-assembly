# frozen_string_literal: true

RSpec.describe JobRunCompleteJob do
  let(:job) { described_class.new }
  let(:job_run) { create(:job_run, :preassembly, state:) }
  let(:completed_accession) { create(:accession, :completed, job_run:) }
  let(:failed_accession) { create(:accession, :failed, job_run:) }
  let(:in_progress_accession) { create(:accession, :in_progress, job_run:) }

  before do
    job_run.accessions = accessions
  end

  context 'when all accessions are completed or failed for preassembly_complete' do
    let(:accessions) { [completed_accession, failed_accession] }
    let(:state) { 'preassembly_complete' }

    it 'transitions the job run to completed' do
      expect { job.perform(job_run) }.to change { job_run.reload.state }.from(state).to('accessioning_complete')
    end
  end

  context 'when all accessions are completed or failed for preassembly_complete_with_errors' do
    let(:accessions) { [completed_accession, failed_accession] }
    let(:state) { 'preassembly_complete_with_errors' }

    it 'transitions the job run to completed' do
      expect { job.perform(job_run) }.to change { job_run.reload.state }.from(state).to('accessioning_complete')
    end
  end

  context 'when some accessions are in progress' do
    let(:accessions) { [completed_accession, failed_accession, in_progress_accession] }
    let(:state) { 'preassembly_complete' }

    it 'does not change the state' do
      expect { job.perform(job_run) }.not_to(change { job_run.reload.state })
    end
  end

  context 'when already complete' do
    let(:accessions) { [completed_accession, failed_accession, in_progress_accession] }
    let(:state) { 'accessioning_complete' }

    it 'does not change the state' do
      expect { job.perform(job_run) }.not_to(change { job_run.reload.state })
    end
  end

  context 'when started but preassembly not completed' do
    let(:accessions) { [completed_accession, failed_accession] }
    let(:state) { 'running' }

    it 'does not change the state' do
      expect { job.perform(job_run) }.not_to(change { job_run.reload.state })
    end
  end
end
