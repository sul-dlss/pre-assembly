# frozen_string_literal: true

RSpec.describe 'Pre-assemble geo object' do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "pdf-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/geo') }
  let(:bare_druid) { 'gn330dv6119' }
  let(:object_staging_dir) { Rails.root.join(DruidTools::Druid.new(bare_druid, Settings.gis_assembly_staging_dir).path) }
  let(:dro_access) { { view: 'world' } }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.geo).new(access: dro_access)
  end
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, current: 1, status:) }
  let(:status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, open?: true, openable?: true, accessioning?: false, version: 1) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item, update: true) }

  before do
    FileUtils.rm_rf(object_staging_dir)

    login_as(user, scope: :user)

    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run)
    allow(PreAssembly::FromStagingLocation::StructuralBuilder).to receive(:build).and_return(item.structural)
  end

  it 'runs successfully, starts gisAssemblyWF and creates log file' do
    visit '/'
    expect(page).to have_css('h1', text: 'Start new job')

    fill_in 'Project name', with: project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Geo', from: 'Content type'
    fill_in 'Staging location', with: staging_location

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
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 2

    expect(PreAssembly::FromStagingLocation::StructuralBuilder).to have_received(:build)
      .with(cocina_dro: item,
            filesets: [], # a blank array for any geo object
            all_files_public: false,
            reading_order: nil,
            manually_corrected_ocr: false)
    expect(dsc_object).to have_received(:update).with(params: item)
    expect(StartAccession).to have_received(:run).with(druid: "druid:#{bare_druid}", batch_context: BatchContext.last, workflow: 'gisAssemblyWF')
  end
end
