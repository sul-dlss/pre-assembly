# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    staging_location { 'spec/fixtures/multimedia' }
    processing_configuration { 'default' }
    content_structure { 'simple_image' }
    project_name { 'Test_Project' }
    staging_style_symlink { false }
    user

    # some tests require Projects with clean output_dir
    factory :project_with_deleted_output_dir do
      after(:build) do |project|
        FileUtils.rm_rf(project.output_dir)
      end
    end

    trait :flat_dir_images do
      staging_location { 'spec/fixtures/flat_dir_images' }
      processing_configuration { 'default' }
      content_structure { 'simple_image' }
      project_name { 'Flat_Dir_Images' }
    end

    trait :folder_manifest do
      staging_location { 'spec/fixtures/obj_dirs_images' }
      processing_configuration { 'default' }
      content_structure { 'simple_image' }
      project_name { 'FolderManifest' }
    end

    trait :public_files do
      all_files_public { true }
    end

    trait :using_file_manifest do
      with_file_manifest { true }
    end
  end
end
