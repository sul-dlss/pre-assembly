# frozen_string_literal: true

RSpec.describe 'Pre-assemble job fails' do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "failed-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/manifest_missing_column') }
  let(:bare_druid) { 'bc123de5678' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'bc', '123', 'de', '5678', bare_druid) }

  before do
    login_as(user, scope: :user)
  end

  it 'fails and does not create log file' do
    visit '/'
    expect(page).to have_css('h1', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Image', from: 'Content structure'
    select 'Group by filename', from: 'Processing configuration'
    fill_in 'Staging location', with: staging_location

    perform_enqueued_jobs do
      click_button 'Submit'
    end

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
