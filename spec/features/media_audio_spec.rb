# frozen_string_literal: true

# Note that media accessioning requires that directories be named for druids and filenames be prefixed by druid
# Note further that there must be (and are) associated md5 files present for every file in the media_manifest.csv
RSpec.describe 'Create Media Audio object', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "media-audio-objects-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/media_audio_test') }
  let(:bare_druid) { 'sn000dd0000' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'sn', '000', 'dd', '0000', bare_druid) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::ObjectType.media, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }
  let(:exp_content_md) do
    <<~XML
      <contentMetadata objectId="sn000dd0000" type="media">
        <resource sequence="1" id="sn000dd0000_1" type="audio">
          <label>Audio file 1</label>
          <file id="sn000dd0000_audio_a_m4a.m4a" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">53b1e299e0277978f0d3f131b9a65a76</checksum>
          </file>
          <file id="sn000dd0000_audio_a_mp3.mp3" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">3675d9ff3dea18a17986b0776f74a218</checksum>
          </file>
          <file id="sn000dd0000_audio_a_wav.wav" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">224646acbdfb7063c902bbd257460fcf</checksum>
          </file>
        </resource>
        <resource sequence="2" id="sn000dd0000_2" type="image">
          <label>Image for audio</label>
          <file id="sn000dd0000_audio_img_1.jpg" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">3e9498107f73ff827e718d5c743f8813</checksum>
          </file>
          <file id="sn000dd0000_audio_img_1.tif" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">4fe3ad7bf975326ff1c1271e8f743ceb</checksum>
          </file>
        </resource>
        <resource sequence="3" id="sn000dd0000_3" type="text">
          <label>Transcript</label>
          <file id="sn000dd0000_audio_pdf.pdf" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">f7169731f4c163f98eed35e1be12a209</checksum>
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

  it do
    visit '/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Media', from: 'Content structure'
    fill_in 'Bundle dir', with: bundle_dir
    select 'Default', from: 'Content metadata creation'
    check 'batch_context_using_file_manifest'

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_link('Download')

    result_file = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    yaml = YAML.load_file(result_file)
    expect(yaml[:status]).to eq 'success'

    # we got all the expected content files
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 12

    content_md_path = File.join(object_staging_dir, 'metadata', 'contentMetadata.xml')
    content_md_xml = File.read(content_md_path)
    expect(noko_doc(content_md_xml)).to be_equivalent_to exp_content_md
  end
end
