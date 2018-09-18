require "rails_helper"

RSpec.describe JobMailer, type: :mailer do
  let(:user) do
    User.new(sunet_id: "Jdoe@stanford.edu")
  end

  let(:bc) do
    BundleContext.new(id: 1,
                      project_name: "SmokeTest",
                      content_structure: 1,
                      bundle_dir: "spec/test_data/images_jp2_tif",
                      staging_style_symlink: false,
                      content_metadata_creation: 1,
                      user: user)
  end

  let(:discovery_report_run) do
    JobRun.new(id: 1,
               output_location: "/path/to/report",
               bundle_context: bc,
               job_type: "discovery_report")
  end

  let(:job_notification) { JobMailer.with(job_run: discovery_report_run).completion_email }

  it 'renders the headers' do
    expect(job_notification.subject).to eq("Your pre-assembly job has completed")
    expect(job_notification.to).to eq(["Jdoe@stanford.edu"])
    expect(job_notification.from).to eq(["no-reply-preassembly-job@stanford.edu"])
  end

  it 'renders the body' do
    expect(job_notification.body.encoded).to include("Your discovery_report job #1 completed")
  end

end
