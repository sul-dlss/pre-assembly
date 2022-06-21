# frozen_string_literal: true

RSpec.describe 'Pre-assemble job fails', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "failed-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/manifest_missing_column') }
  let(:bare_druid) { 'bc123de5678' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'bc', '123', 'de', '5678', bare_druid) }

  before do
    login_as(user, scope: :user)
  end

  # have background jobs run synchronously
  include ActiveJob::TestHelper
  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  it 'fails and does not create log file' do
    visit '/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Image', from: 'Content structure'
    fill_in 'Staging location', with: bundle_dir
    click_button 'Submit'

    # it fails before this:
    # exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    # expect(page).to have_content exp_str

    # go to job details page
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_content 'Failed'
    expect(page).to have_content 'manifest must have "druid" and "object" columns'
    expect(page).to have_content 'No progress log file is available'

    # we got no content files
    expect(Dir.exist?(object_staging_dir)).to be false
  end
end
