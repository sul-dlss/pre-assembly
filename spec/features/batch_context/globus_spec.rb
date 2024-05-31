# frozen_string_literal: true

RSpec.describe 'Use Globus staging location', :js do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:globus_dir) { Pathname(Rails.root.join('tmp/globus')) }

  before do
    globus_dir.rmtree if globus_dir.directory?
    globus_dir.mkpath
    allow(Settings.globus).to receive(:directory).and_return(globus_dir.to_s)

    allow(GlobusClient).to receive(:mkdir).and_return(true)
    login_as(user, scope: :user)
  end

  it 'creates GlobusDestination' do
    visit '/'
    expect(GlobusDestination.count).to eq(0)
    click_button 'Request Globus Link'
    expect(GlobusDestination.count).to eq(1)
    globus_dest = GlobusDestination.first
    expect(page).to have_field('Staging location', with: globus_dest.url)
  end

  it 'can create BatchContext with Globus URL' do
    visit '/'
    fill_in 'Project name', with: "test-#{Time.now.to_i}"
    select 'Image', from: 'Content type'
    select 'Group by filename', from: 'Processing configuration'

    # click to create a Globus share and get the new GlobusDestination
    click_button 'Request Globus Link'
    globus_dest = GlobusDestination.first

    # simulate Globus moving the data into place
    Pathname(globus_dest.staging_location).parent.mkdir
    FileUtils.cp_r(Rails.root.join('spec/fixtures/book-file-manifest/'), globus_dest.staging_location)

    # submit the form to create the BatchContext and link it up with the GlobusDestination
    click_button 'Submit'
    expect(page).to have_content('Success! Your job is queued.')
    expect(BatchContext.count).to eq(1)
    expect(BatchContext.all[0].globus_destination).to eq(globus_dest)
  end

  it 'can create BatchContext with Globus destination path' do
    visit '/'
    fill_in 'Project name', with: "test-#{Time.now.to_i}"
    select 'Image', from: 'Content type'
    select 'Group by filename', from: 'Processing configuration'

    # click to create a Globus share and get the new GlobusDestination
    click_button 'Request Globus Link'
    globus_dest = GlobusDestination.first

    # put the staging path into the location field
    fill_in 'Staging location', with: globus_dest.staging_location

    # simulate Globus moving the data into place
    Pathname(globus_dest.staging_location).parent.mkdir
    FileUtils.cp_r(Rails.root.join('spec/fixtures/book-file-manifest/'), globus_dest.staging_location)

    # submit the form to create the BatchContext and link it up with the GlobusDestination
    click_button 'Submit'
    expect(page).to have_content('Success! Your job is queued.')
    expect(BatchContext.count).to eq(1)
    expect(BatchContext.all[0].globus_destination).to eq(globus_dest)
  end

  it 'disallows creation when there are >= 99 active GlobusDestinations' do
    99.times do
      GlobusDestination.create(user:, deleted_at: nil)
    end

    # make sure they can't create any more
    visit '/'
    click_button 'Request Globus Link'
    expect(find_by_id('globus-error')).to have_content('You have too many Globus shares. Please contact sdr-contact@lists.stanford.edu for help.')
    expect(GlobusDestination.count).to eq(99)
  end

  it 'allows creation when there are >= 99 inactive GlobusDestinations' do
    101.times do
      GlobusDestination.create(user:, deleted_at: DateTime.now)
    end

    # make sure they can still create
    visit '/'
    click_button 'Request Globus Link'
    expect(GlobusDestination.count).to eq(102)
  end
end
