# frozen_string_literal: true

RSpec.describe 'Run preassembly on object with no files' do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "no-files-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/media_missing') }
  let(:bare_druid) { 'aa111aa1111' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'aa', '111', 'aa', '1111', bare_druid) }
  let(:dro_access) { { view: 'world' } }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.object).new(access: dro_access)
  end
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, current: 1, open: true, status:) }
  let(:status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, open?: false, openable?: true, accessioning?: false, version: 1) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item, update: true) }

  before do
    FileUtils.rm_rf(object_staging_dir)

    login_as(user, scope: :user)

    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run)
  end

  # the manifest for this fixture references an object folder that is not in the staging location,
  # so accessioning it would delete the files already in the repository
  it 'has status "Preassembly completed (with errors)" and does not accession the object' do
    visit '/'
    expect(page).to have_css('h1', text: 'Start new job')

    fill_in 'Project name', with: project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Image', from: 'Content type'
    fill_in 'Staging location', with: staging_location

    perform_enqueued_jobs do
      click_button 'Submit'
    end
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_text exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_text project_name
    expect(page).to have_text '1 objects had errors during pre-assembly'
    expect(page).to have_link('Download').once

    result_file = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    yaml = YAML.load_file(result_file)
    expect(yaml[:status]).to eq 'error'
    expect(yaml[:message]).to eq "can't be accessioned -- the object folder was not found in the staging location: " \
                                 "#{staging_location}/#{bare_druid}"

    # nothing was staged, no version was opened, and the object was not accessioned
    expect(Dir.exist?(object_staging_dir)).to be false
    expect(dsc_object_version).not_to have_received(:open)
    expect(dsc_object).not_to have_received(:update)
    expect(StartAccession).not_to have_received(:run)
  end
end
