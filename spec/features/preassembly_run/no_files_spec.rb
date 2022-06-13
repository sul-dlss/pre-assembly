# frozen_string_literal: true

RSpec.describe 'Run preassembly on object with no files', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "no-files-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/media_missing') }
  let(:bare_druid) { 'aa111aa1111' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'aa', '111', 'aa', '1111', bare_druid) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::ObjectType.image, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }
  let(:exp_content_md) do
    <<~XML
      <contentMetadata objectId="aa111aa1111" type="image"/>
    XML
  end

  before do
    login_as(user, scope: :user)
    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid}", user: user.sunet_id)
  end

  after do
    FileUtils.remove_dir(object_staging_dir) if Dir.exist?(object_staging_dir)
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
    fill_in 'Bundle dir', with: bundle_dir

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

    metadata_dir = File.join(object_staging_dir, 'metadata')
    expect(Dir.children(metadata_dir).size).to eq 1

    content_md_xml = File.read(File.join(metadata_dir, 'contentMetadata.xml'))
    expect(noko_doc(content_md_xml)).to be_equivalent_to exp_content_md
  end
end
