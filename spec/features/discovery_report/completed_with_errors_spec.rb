# frozen_string_literal: true

require 'axe-rspec'

RSpec.describe 'Discovery Report completes with errors', :js do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "discovery-report-completed-with-errors-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/good_and_error_objects') }
  let(:bare_druid) { 'oo000oo0000' }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.book).new(access: { view: 'world' })
  end
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, status:) }
  let(:status) { instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, openable?: false, version: 2) }
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

  it 'shows errors and has report and log files' do
    visit '/'
    expect(page).to have_css('h1', text: 'Start new job')

    fill_in 'Project name', with: project_name
    select 'Discovery Report', from: 'Job type'
    select 'Image', from: 'Content type'
    fill_in 'Staging location', with: staging_location

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_content 'Discovery report completed (with errors)'
    expect(page).to have_content 'Errors'
    expect(page).to have_content '1 objects had errors in the discovery report'
    expect(page).to have_link('Download').twice

    # summary table
    expect(page).to have_content '250 KB'
    expect(page).to have_content 'image/tiff : 4'
    expect(page).to have_content 'less than a minute'
    # error table
    expect(page).to have_content 'Errors Summary'
    expect(page).to have_content 'druid:oo111oo1111'
    expect(page).to have_content 'empty_object : true'
    expect(page).to have_content 'missing_files : true'

    # discovery report JSON produced
    report_path = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, 'discovery_report_*.json')
    report_file = Dir[report_path].first
    discovery_report_json = JSON.parse(File.read(report_file))
    expect(discovery_report_json['rows'].first['druid']).to eq "druid:#{bare_druid}"
    expect(discovery_report_json['rows'][1]['errors']).to match({ 'empty_object' => true, 'missing_files' => true })
    expect(discovery_report_json['summary']['objects_with_error'].size).to eq 1
    expect(discovery_report_json['summary']['mimetypes']['image/tiff']).to eq 4

    # output log file produced
    log_path = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, "#{project_name}_progress.yml")
    log = File.read(log_path)
    expect(log.scan(/status:\s+success/m).length).to eq 2
    expect(log.scan(/status:\s+error/m).length).to eq 1

    expect(page).to be_axe_clean
    visit '/'
    expect(page).to be_axe_clean
  end
end
