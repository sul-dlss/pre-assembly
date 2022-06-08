# frozen_string_literal: true

RSpec.describe 'Discovery Report creation using build manifest', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "discovery-report-image-#{RandomWord.nouns.next}" }
  let(:bundle_dir) { Rails.root.join('spec/test_data/image_jpg') }
  let(:bare_druid) { 'pr666rr9999' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'pr', '666', 'rr', '9999', bare_druid) }
  let(:cocina_model_world_access) { instance_double(Cocina::Models::Access, view: 'world') }
  let(:item) { instance_double(Cocina::Models::DRO, type: Cocina::Models::ObjectType.image, access: cocina_model_world_access) }
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item) }

  before do
    FileUtils.remove_dir(object_staging_dir) if Dir.exist?(object_staging_dir)

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

  it do
    visit '/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: project_name
    select 'Discovery Report', from: 'Job type'
    select 'Image', from: 'Content structure'
    fill_in 'Bundle dir', with: bundle_dir

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, wait for preassembly to finish
    first('td  > a').click
    expect(page).to have_content project_name
    expect(page).to have_link('Download')

    result_path = Rails.root.join(Settings.job_output_parent_dir, user_id, project_name, 'discovery_report_*.json')
    result_file = Dir[result_path].first
    discovery_report_json = JSON.parse(File.read(result_file))
    expect(discovery_report_json['summary']['objects_with_error']).to eq 0
    expect(discovery_report_json['rows'].first['druid']).to eq "druid:#{bare_druid}"
    expect(discovery_report_json['summary']['mimetypes']['image/jpeg']).to eq 1
  end
end
