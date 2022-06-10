# frozen_string_literal: true

RSpec.describe 'job_runs/show.html.erb', type: :view do
  before do
    assign(:job_run, job_run)
    allow(job_run).to receive(:progress_log_file).and_return(actual_file)
    allow(job_run).to receive(:output_location).and_return(actual_file)
  end

  let(:job_run) { create(:job_run, :discovery_report) }
  let(:actual_file) { Rails.root.join('spec/test_data/input/mock_progress_log.yaml') } # an existing file we can use for tests

  context 'discovery_report job' do
    it 'displays a job_run' do
      render template: 'job_runs/show'
      expect(rendered).to include("Discovery report \##{job_run.id}")
    end

    it 'with a completed job, presents a download link to the report and the log file' do
      job_run.started
      job_run.completed
      render template: 'job_runs/show'
      expect(rendered).to include("<a href=\"/job_runs/#{job_run.id}/download_log\">Download</a>")
      expect(rendered).to include("<a href=\"/job_runs/#{job_run.id}/download_report\">Download</a>")
    end

    it 'with an incomplete job, urges user patience and does not link to report or log' do
      render template: 'job_runs/show'
      expect(rendered).to include('Job is not yet complete')
      expect(rendered).not_to include("<a href=\"/job_runs/#{job_run.id}/download_log\">Download</a>")
      expect(rendered).not_to include("<a href=\"/job_runs/#{job_run.id}/download_report\">Download</a>")
    end

    it 'displays user email from batch context' do
      render template: 'job_runs/show'
      expect(rendered).to include(job_run.batch_context.user.email)
    end

    it 'displays an error message if present' do
      job_run.error_message = 'Oops, that was bad.'
      render template: 'job_runs/show'
      expect(rendered).to include('Oops, that was bad.')
    end
  end

  context 'preassembly job' do
    let(:job_run) { create(:job_run, :preassembly) }

    it 'displays a job_run' do
      render template: 'job_runs/show'
      expect(rendered).to include("Preassembly \##{job_run.id}")
    end

    it 'with a completed job, presents a download link to only the log file' do
      job_run.started
      job_run.completed
      render template: 'job_runs/show'
      expect(rendered).to include("<a href=\"/job_runs/#{job_run.id}/download_log\">Download</a>")
      expect(rendered).not_to include("<a href=\"/job_runs/#{job_run.id}/download_report\">Download</a>")
    end

    it 'with an incomplete job, urges user patience and does not link to report or log' do
      render template: 'job_runs/show'
      expect(rendered).to include('Job is not yet complete')
      expect(rendered).not_to include("<a href=\"/job_runs/#{job_run.id}/download_log\">Download</a>")
      expect(rendered).not_to include("<a href=\"/job_runs/#{job_run.id}/download_report\">Download</a>")
    end

    it 'displays an error message if present' do
      job_run.error_message = 'Oops, that was bad.'
      render template: 'job_runs/show'
      expect(rendered).to include('Oops, that was bad.')
    end
  end

  context 'with missing log file' do
    before { allow(job_run).to receive(:progress_log_file).and_return('') } # no file available

    it 'with a failed job, it does not link to the log file which does not exist' do
      job_run.started
      job_run.failed
      render template: 'job_runs/show'
      expect(rendered).to include('No progress log file is available.')
      expect(rendered).not_to include("<a href=\"/job_runs/#{job_run.id}/download_log\">Download</a>")
    end
  end
end
