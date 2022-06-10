# frozen_string_literal: true

RSpec.describe 'Pre assemble job completes with errors', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "complete-with-errors-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/good_and_error_objects') }
  let(:bare_druid1) { 'oo000oo0000' }
  let(:bare_druid2) { 'oo111oo1111' }
  let(:bare_druid3) { 'oo222oo2222' }
  let(:object_staging_dir1) { Rails.root.join(Settings.assembly_staging_dir, 'oo', '000', 'oo', '0000', bare_druid1) }
  let(:object_staging_dir3) { Rails.root.join(Settings.assembly_staging_dir, 'oo', '222', 'oo', '2222', bare_druid3) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::ObjectType.image, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }
  let(:exp_content_md1) do
    <<~XML
      <contentMetadata objectId="oo000oo0000" type="image">
        <resource id="oo000oo0000" sequence="1" type="image">
          <label>Image 1</label>
          <file id="image1.tif">
            <checksum type="md5">3e9498107f73ff827e718d5c743f8813</checksum>
          </file>
        </resource>
        <resource id="oo000oo0000" sequence="2" type="image">
          <label>Image 2</label>
          <file id="image2.tif">
            <checksum type="md5">3e9498107f73ff827e718d5c743f8813</checksum>
          </file>
        </resource>
      </contentMetadata>
    XML
  end
  let(:exp_content_md2) do
    <<~XML
      <contentMetadata objectId="oo222oo2222" type="image">
        <resource id="oo222oo2222" sequence="1" type="image">
          <label>Image 1</label>
          <file id="image1.tif">
            <checksum type="md5">3e9498107f73ff827e718d5c743f8813</checksum>
          </file>
        </resource>
        <resource id="oo222oo2222" sequence="2" type="image">
          <label>Image 2</label>
          <file id="image2.tif">
            <checksum type="md5">3e9498107f73ff827e718d5c743f8813</checksum>
          </file>
        </resource>
      </contentMetadata>
    XML
  end

  before do
    FileUtils.remove_dir(object_staging_dir1) if Dir.exist?(object_staging_dir1)
    FileUtils.remove_dir(object_staging_dir3) if Dir.exist?(object_staging_dir3)

    login_as(user, scope: :user)

    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid1}", user: user.sunet_id)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid2}", user: user.sunet_id)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid3}", user: user.sunet_id)
  end

  # have background jobs run synchronously
  include ActiveJob::TestHelper
  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  it 'completes with errors and creates log file' do
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
    expect(page).to have_content 'Completed (with errors)'
    expect(page).to have_content 'Errors'
    expect(page).to have_content '1 objects had no files'
    expect(page).to have_link('Download').once

    log_path = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    log = File.read(log_path)
    expect(log.scan(/status:\s+success/m).length).to eq 2
    expect(log.scan(/status:\s+error/m).length).to eq 1

    # we got all the expected content files
    expect(Dir.children(File.join(object_staging_dir1, 'content')).size).to eq 1
    metadata_dir = File.join(object_staging_dir1, 'metadata')
    expect(Dir.children(metadata_dir).size).to eq 1
    expect(noko_doc(File.read(File.join(metadata_dir, 'contentMetadata.xml')))).to be_equivalent_to exp_content_md1

    expect(Dir.children(File.join(object_staging_dir2, 'content')).size).to eq 1
    metadata_dir = File.join(object_staging_dir2, 'metadata')
    expect(Dir.children(metadata_dir).size).to eq 1
    expect(noko_doc(File.read(File.join(metadata_dir, 'contentMetadata.xml')))).to be_equivalent_to exp_content_md2
  end
end
