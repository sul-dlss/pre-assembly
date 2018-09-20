RSpec.describe JobMailer, type: :mailer do
  let(:bc) { build(:bundle_context) }
  let(:job_run) do
    JobRun.new(id: 1,
               output_location: "/path/to/report",
               bundle_context: bc,
               job_type: "discovery_report")
  end
  let(:job_notification) { described_class.with(job_run: job_run).completion_email }

  it 'renders the headers' do
    expect(job_notification.subject).to eq("Your pre-assembly job has completed")
    expect(job_notification.to).to eq([job_run.bundle_context.user.email])
    expect(job_notification.from).to eq(["no-reply-preassembly-job@stanford.edu"])
  end

  it 'renders the body' do
    expect(job_notification.body.encoded).to include("Your discovery_report job #1 completed")
  end
end
