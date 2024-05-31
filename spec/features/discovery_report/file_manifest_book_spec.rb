# frozen_string_literal: true

# Note that media accessioning requires that directories be named for druids and filenames be prefixed by druid
# Note further that there must be (and are) associated md5 files present for every file in the media_manifest.csv
#
# this test uses file_manifest.csv approach
RSpec.describe 'Discovery Report from file_manifest.csv' do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "discovery-report-book-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/book-file-manifest') }
  let(:bare_druid) { 'bb000kk0000' }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.book).new(access: { view: 'world' })
  end
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true, current: 2) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }

  before do
    login_as(user, scope: :user)
    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
  end

  # have background jobs run synchronously
  include ActiveJob::TestHelper
  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  it 'provides report and log files' do
    visit '/'
    expect(page).to have_css('h1', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Discovery Report', from: 'Job type'
    fill_in 'Staging location', with: staging_location
    select 'Book', from: 'Content type'
    select('Default', from: 'Processing configuration') unless Settings.ocr.enabled
    check 'batch_context_using_file_manifest'

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_link('Download').twice

    result_path = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, 'discovery_report_*.json')
    result_file = Dir[result_path].first
    discovery_report_json = JSON.parse(File.read(result_file))
    expect(discovery_report_json['summary']['objects_with_error']).to be_empty
    expect(discovery_report_json['rows'].first['druid']).to eq "druid:#{bare_druid}"
    expect(discovery_report_json['summary']['mimetypes']['image/jpeg']).to eq 3
    # verify the timestamps in the summary are for today
    expect(discovery_report_json['summary']['start_time'].to_date).to eq Time.now.utc.to_date
    expect(discovery_report_json['summary']['end_time'].to_date).to eq Time.now.utc.to_date

    log_path = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    log_hash = YAML.load_file(log_path)
    expect(log_hash).to include(status: 'success', pid: bare_druid, discovery_finished: true)
    expect(log_hash.keys.size).to eq 4
  end
end
