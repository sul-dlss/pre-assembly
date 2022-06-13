# frozen_string_literal: true

RSpec.describe 'Create Public object (shelved and published)', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "image-#{RandomWord.nouns.next}" }
  # tif files are dark by default
  #  see https://github.com/sul-dlss/assembly-objectfile/blob/master/lib/assembly-objectfile/content_metadata/file.rb#L9-L27
  let(:bundle_dir) { Rails.root.join('spec/test_data/image_tif') }
  let(:bare_druid) { 'tf111tf2222' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'tf', '111', 'tf', '2222', bare_druid) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::ObjectType.image, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }
  let(:exp_content_md) do
    <<~XML
      <contentMetadata objectId="tf111tf2222" type="image">
        <resource id="tf111tf2222_1" sequence="1" type="image">
          <label>Image 1</label>
          <file id="tif.tif" preserve="yes" shelve="yes" publish="yes">
            <checksum type="md5">4fe3ad7bf975326ff1c1271e8f743ceb</checksum>
          </file>
        </resource>
      </contentMetadata>
    XML
  end

  before do
    FileUtils.remove_dir(object_staging_dir) if Dir.exist?(object_staging_dir)

    login_as(user, scope: :user)

    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid}", user: user.sunet_id)
  end

  # have background jobs run synchronously
  include ActiveJob::TestHelper
  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  it 'runs successfully and creates log file' do
    visit '/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Image', from: 'Content structure'
    fill_in 'Bundle dir', with: bundle_dir
    choose 'Preserve=Yes, Shelve=Yes, Publish=Yes'

    click_button 'Submit'
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
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 1

    metadata_dir = File.join(object_staging_dir, 'metadata')
    expect(Dir.children(metadata_dir).size).to eq 1

    content_md_xml = File.read(File.join(metadata_dir, 'contentMetadata.xml'))
    expect(noko_doc(content_md_xml)).to be_equivalent_to exp_content_md
  end
end
