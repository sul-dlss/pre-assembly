# frozen_string_literal: true

RSpec.describe JobMailer do
  let(:job_notification) { described_class.with(job_run:).completion_error_email }

  context 'when a discovery report' do
    let(:job_run) { create(:job_run, :discovery_report, objects_with_error: ['bbb111ccc1111']) }

    it 'renders the headers' do
      expect(job_notification.subject).to eq('[Test_Project] Your Discovery report job encountered errors')
      expect(job_notification.to).to eq([job_run.batch_context.user.email])
      expect(job_notification.from).to eq(['no-reply-preassembly-job@stanford.edu'])
    end

    it 'renders the body' do
      expect(job_notification.body.encoded).to match(/Your Discovery report job #\d+ encountered errors./)
        .and include('The following 1 object in your')
        .and include("http://localhost:3000/job_runs/#{job_run.id}")
        .and include('mailto:CHANGE_ME@stanford.edu')
    end
  end

  context 'when a preassembly' do
    let(:job_run) { create(:job_run, :preassembly) }

    it 'renders the headers' do
      expect(job_notification.subject).to eq('[Test_Project] Your Preassembly job encountered errors')
    end
  end
end
