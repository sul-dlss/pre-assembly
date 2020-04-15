# frozen_string_literal: true

require 'fileutils'
require 'random_word'

RSpec.describe 'Create Media Video object', type: :feature do
  include ActiveJob::TestHelper # have background jobs run synchronously

  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "media-video-objects-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/media_video_test') }
  let(:bare_druid) { 'vd000bj0000' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'vd', '000', 'bj', '0000', bare_druid) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, access: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::Vocab.media, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }
  let(:exp_content_md) do
    <<~XML
      <contentMetadata objectId="vd000bj0000" type="media">
        <resource sequence="1" id="vd000bj0000_1" type="video">
          <label>Video file 1</label>
          <file id="vd000bj0000_video_1.mp4" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">ee4e90be549c5614ac6282a5b80a506b</checksum>
          </file>
          <file id="vd000bj0000_video_1.mpeg" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">bed85c6ffc2f8070599a7fb682852f30</checksum>
          </file>
          <file id="vd000bj0000_video_1_thumb.jp2" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">4b0e92aec76da9ac98567b8e6848e922</checksum>
          </file>
        </resource>
        <resource sequence="2" id="vd000bj0000_2" type="video">
          <label>Video file 2</label>
          <file id="vd000bj0000_video_2.mp4" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">ee4e90be549c5614ac6282a5b80a506b</checksum>
          </file>
          <file id="vd000bj0000_video_2.mpeg" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">bed85c6ffc2f8070599a7fb682852f30</checksum>
          </file>
          <file id="vd000bj0000_video_2_thumb.jp2" preserve="yes" publish="yes" shelve="yes">
            <checksum type="md5">4b0e92aec76da9ac98567b8e6848e922</checksum>
          </file>
        </resource>
        <resource sequence="3" id="vd000bj0000_3" type="image">
          <label>Image of media (1 of 2)</label>
          <file id="vd000bj0000_video_img_1.tif" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">4fe3ad7bf975326ff1c1271e8f743ceb</checksum>
          </file>
        </resource>
        <resource sequence="4" id="vd000bj0000_4" type="image">
          <label>Image of media (2 of 2)</label>
          <file id="vd000bj0000_video_img_2.tif" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">4fe3ad7bf975326ff1c1271e8f743ceb</checksum>
          </file>
        </resource>
        <resource sequence="5" id="vd000bj0000_5" type="file">
          <label>Disc log file</label>
          <file id="vd000bj0000_video_log.txt" preserve="yes" publish="no" shelve="no">
            <checksum type="md5">b659a852e4f0faa2f1d83973446a4ee9</checksum>
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
    select 'Media', from: 'Content metadata creation'

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, download result when finished
    first('td  > a').click
    expect(page).to have_content project_name
    # p project_name # useful for debugging

    # wait for preassembly to finish
    expect(page).to have_link('Download')

    result_file = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    yaml = YAML.load_file(result_file)
    expect(yaml[:status]).to eq 'success'

    # we got all the expected content files
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 18

    metadata_dir = File.join(object_staging_dir, 'metadata')
    expect(Dir.children(metadata_dir).size).to eq 2

    content_md_xml = File.open(File.join(metadata_dir, 'contentMetadata.xml')).read
    expect(noko_doc(content_md_xml)).to be_equivalent_to exp_content_md

    # note that technicalMetadata.xml is created, but we don't care about it anymore due to new technical-metadata-service
  end
end
