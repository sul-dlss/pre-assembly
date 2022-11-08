# frozen_string_literal: true

# hierarchical files without a file manifest (i.e. normal filesystem discovery)
RSpec.describe 'Pre-assemble Image object', type: :feature do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }
  let(:project_name) { "hierarchical-image-#{RandomWord.nouns.next}" }
  let(:staging_location) { Rails.root.join('spec/fixtures/hierarchical-files') }
  let(:bare_druid) { 'mm111mm2222' }
  let(:object_staging_dir) { Rails.root.join(Settings.assembly_staging_dir, 'mm', '111', 'mm', '2222', bare_druid) }
  let(:dro_access) { { view: 'world' } }
  let(:item) do
    Cocina::RSpec::Factories.build(:dro, type: Cocina::Models::ObjectType.image).new(access: dro_access)
  end
  let(:dsc_object_version) { instance_double(Dor::Services::Client::ObjectVersion, openable?: true) }
  let(:dsc_object) { instance_double(Dor::Services::Client::Object, version: dsc_object_version, find: item, update: true) }

  before do
    FileUtils.rm_rf(object_staging_dir)

    login_as(user, scope: :user)

    allow(Dor::Services::Client).to receive(:object).and_return(dsc_object)
    allow(StartAccession).to receive(:run).with(druid: "druid:#{bare_druid}", user: user.sunet_id)
    allow(PreAssembly::FromStagingLocation::StructuralBuilder).to receive(:build).and_return(item.structural)
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
    fill_in 'Staging location', with: staging_location

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

    # we got all the expected content files and folders, and they are staged correctly in sub-folders
    content_root = File.join(object_staging_dir, 'content')
    staged_files_and_folders = Dir.glob("#{content_root}/**/**")
    expect(staged_files_and_folders.size).to eq 11
    expect(staged_files_and_folders).to eq ["#{content_root}/config",
                                            "#{content_root}/config/settings",
                                            "#{content_root}/config/settings/test.yml",
                                            "#{content_root}/config/settings/test1.yml",
                                            "#{content_root}/config/settings/test2.yml",
                                            "#{content_root}/config/test.yml",
                                            "#{content_root}/images",
                                            "#{content_root}/images/image.jpg",
                                            "#{content_root}/images/subdir",
                                            "#{content_root}/images/subdir/image.jpg",
                                            "#{content_root}/test1.txt"]

    expect(PreAssembly::FromStagingLocation::StructuralBuilder).to have_received(:build)
      .with(cocina_dro: item,
            filesets: Array,
            all_files_public: false,
            reading_order: 'left-to-right',
            content_md_creation_style: :simple_image)
    expect(dsc_object).to have_received(:update).with(params: item)
  end
end