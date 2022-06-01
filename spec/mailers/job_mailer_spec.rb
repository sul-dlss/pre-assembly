# frozen_string_literal: true

RSpec.describe JobMailer, type: :mailer do
  let(:job_run) { create(:job_run, :discovery_report) }
  let(:job_notification) { described_class.with(job_run: job_run).completion_email }

  it 'renders the headers' do
    expect(job_notification.subject).to eq('[Test_Project] Your Discovery report job completed')
    expect(job_notification.to).to eq([job_run.batch_context.user.email])
    expect(job_notification.from).to eq(['no-reply-preassembly-job@stanford.edu'])
  end

  describe 'subject' do
    before { job_run.job_type = 1 }

    it 'adapts depending on job_type' do
      expect(job_notification.subject).to eq('[Test_Project] Your Preassembly job completed')
    end
  end

  it 'renders the body' do
    expect(job_notification.body.encoded).to include("Your Discovery report job \##{job_run.id} completed")
      .and include("http://localhost:3000/job_runs/#{job_run.id}")
  end
end
