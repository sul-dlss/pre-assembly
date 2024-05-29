# frozen_string_literal: true

# Note that media accessioning requires that directories be named for druids and filenames be prefixed by druid
# Note further that there must be (and are) associated md5 files present for every file in the media_manifest.csv
#
# this test uses file_manifest.csv approach
RSpec.describe 'Pre-assemble Media Video object' do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "media-video-objects-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/media_video_test') }
  let(:bare_druid) { 'vd000bj0000' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'vd', '000', 'bj', '0000', bare_druid) }
  let(:dro_access) { { view: 'world' } }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.media).new(access: dro_access)
  end
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true, current: 1, status:) }
  let(:status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, open?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item, update: true) }
  let(:workflow_client) { instance_double(Dor::Workflow::Client, active_lifecycle: nil) }

  before do
    FileUtils.rm_rf(object_staging_dir)

    login_as(user, scope: :user)

    allow(Dor::Workflow::Client).to receive(:new).and_return(workflow_client)
    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run)
    allow(PreAssembly::FromFileManifest::StructuralBuilder).to receive(:build).and_return(item.structural)
  end

  it 'works with a video object with a valid role in contentMetadata' do
    visit '/'
    expect(page).to have_css('h1', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Media', from: 'Content type'
    fill_in 'Staging location', with: staging_location
    select 'Default', from: 'Processing configuration'
    check 'batch_context_using_file_manifest'

    perform_enqueued_jobs do
      click_button 'Submit'
    end
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_link('Download').once

    result_file = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    yaml = YAML.load_file(result_file)
    expect(yaml[:status]).to eq 'success'

    # we got all the expected content files
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 18

    expect(PreAssembly::FromFileManifest::StructuralBuilder).to have_received(:build)
      .with(cocina_dro: item,
            resources: Hash,
            reading_order: nil,
            staging_location: staging_location.to_s)
    expect(dsc_object).to have_received(:update).with(params: item)
    expect(StartAccession).to have_received(:run).with(druid: "druid:#{bare_druid}", batch_context: BatchContext.last, workflow: 'assemblyWF')
  end
end
