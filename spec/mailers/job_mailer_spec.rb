RSpec.describe JobMailer, type: :mailer do
  let(:job_run) { create(:job_run) }
  let(:job_notification) { described_class.with(job_run: job_run).completion_email }

  it 'renders the headers' do
    expect(job_notification.subject).to eq("Your pre-assembly job has completed")
    expect(job_notification.to).to eq([job_run.bundle_context.user.email])
    expect(job_notification.from).to eq(["no-reply-preassembly-job@stanford.edu"])
  end

  it 'renders the body' do
    expect(job_notification.body.encoded).to include("Your discovery_report job \##{job_run.id} completed")
  end
end
