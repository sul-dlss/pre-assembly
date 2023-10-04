# frozen_string_literal: true

RSpec.describe 'Job run process log' do
  let(:objects_with_error) { ['vp571pm1869'] }
  let(:job_run) { create(:job_run, :preassembly, objects_with_error:) }

  before do
    create(:accession, state: 'completed', druid: 'vp571pm1867', job_run:)
    create(:accession, state: 'in_progress', druid: 'vp571pm1868', job_run:)
    create(:accession, state: 'failed', druid: 'vp571pm1868', job_run:)
    sign_in(create(:user))
  end

  it 'shows the log' do
    get "/job_runs/#{job_run.id}/process_log"
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Preassembly error')
    expect(response.body).to include('Accessioning in progress')
    expect(response.body).to include('Accessioning failed')
    expect(response.body).to include('Accessioning success')
  end
end
