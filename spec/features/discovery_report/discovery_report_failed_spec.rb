# frozen_string_literal: true

RSpec.describe 'Discovery Report fails', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "discovery-report-failed-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/file_manifest_no_header') }

  before do
    login_as(user, scope: :user)
    allow(Dor::Services::Client).to receive(:object)
  end

  # have background jobs run synchronously
  include ActiveJob::TestHelper
  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  it 'has no report and progress log shows status failed' do
    visit '/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Discovery Report', from: 'Job type'
    fill_in 'Bundle dir', with: bundle_dir
    check 'batch_context_using_file_manifest'

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_content 'Failed'
    expect(page).to have_content "undefined method `find' for nil:NilClass"
    expect(page).to have_content 'No progress log file is available'
  end
end
