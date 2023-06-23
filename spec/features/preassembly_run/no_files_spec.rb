# frozen_string_literal: true

RSpec.describe 'Run preassembly on object with no files' do
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
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true, current: 1) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item, update: true) }
  let(:workflow_client) { instance_double(Dor::Workflow::Client, active_lifecycle: nil) }

  before do
    FileUtils.rm_rf(object_staging_dir)

    login_as(user, scope: :user)

    allow(Dor::Workflow::Client).to receive(:new).and_return(workflow_client)
    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid}", user: user.sunet_id)
    allow(PreAssembly::FromStagingLocation::StructuralBuilder).to receive(:build).and_return(item.structural)
  end

  # have background jobs run synchronously
  include ActiveJob::TestHelper
  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  it 'has status "Completed" and creates log file showing "success"' do
    visit '/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Image', from: 'Content structure'
    fill_in 'Staging location', with: staging_location

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_content 'Completed'
    expect(page).to have_link('Download').once

    result_file = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    yaml = YAML.load_file(result_file)
    expect(yaml[:status]).to eq 'success'

    # we got all the expected content files
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 0

    expect(PreAssembly::FromStagingLocation::StructuralBuilder).to have_received(:build)
      .with(cocina_dro: item,
            filesets: [],
            all_files_public: false,
            reading_order: 'left-to-right',
            content_md_creation_style: :file)
    expect(dsc_object).to have_received(:update).with(params: item)
  end
end
