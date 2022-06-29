# frozen_string_literal: true

# this test uses file_manifest.csv approach
RSpec.describe 'Pre-assemble Book Using File Manifest', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "book-file-manifest-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/test_data/book-file-manifest') }
  let(:bare_druid) { 'bb000kk0000' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'bb', '000', 'kk', '0000', bare_druid) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::ObjectType.book, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }
  let(:exp_content_md) do
    <<~XML
      <contentMetadata objectId="bb000kk0000" type="book">
        <bookData readingOrder='rtl'/>
        <resource sequence="1" id="bb000kk0000_1" type="page">
          <label>page 1</label>
          <file id="page_0001.jpg" preserve="yes" publish="no" shelve="no"/>
          <file id="page_0001.pdf" preserve="yes" publish="yes" shelve="yes"/>
          <file id="page_0001.xml" preserve="yes" publish="yes" shelve="yes" role="transcription"/>
        </resource>
        <resource sequence="2" id="bb000kk0000_2" type="page">
          <label>page 2</label>
          <file id="page_0002.jpg" preserve="yes" publish="no" shelve="no"/>
          <file id="page_0002.pdf" preserve="yes" publish="yes" shelve="yes"/>
          <file id="page_0002.xml" preserve="yes" publish="yes" shelve="yes" role="transcription"/>
        </resource>
        <resource sequence="3" id="bb000kk0000_3" type="page">
          <label>page 3</label>
          <file id="page_0003.jpg" preserve="yes" publish="no" shelve="no"/>
          <file id="page_0003.pdf" preserve="yes" publish="yes" shelve="yes"/>
          <file id="page_0003.xml" preserve="yes" publish="yes" shelve="yes" role="transcription"/>
        </resource>
      </contentMetadata>
    XML
  end

  before do
    FileUtils.rm_rf(object_staging_dir)

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
    select 'Book (rtl)', from: 'Content structure'
    fill_in 'Staging location', with: staging_location
    select 'Default', from: 'Content metadata creation'
    check 'batch_context_using_file_manifest'

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
    expect(Dir.children(File.join(object_staging_dir, 'content')).size).to eq 9

    content_md_path = File.join(object_staging_dir, 'metadata', 'contentMetadata.xml')
    content_md_xml = File.read(content_md_path)
    expect(content_md_xml).to be_equivalent_to(exp_content_md)
  end
end
