# frozen_string_literal: true

FactoryBot.define do
  factory :batch_context do
    staging_location { 'spec/test_data/multimedia' }
    content_metadata_creation { 'default' }
    content_structure { 'simple_image' }
    project_name { 'Test_Project' }
    staging_style_symlink { false }
    user

    # some tests require BCs with clean output_dir
    factory :batch_context_with_deleted_output_dir do
      after(:build) do |bc|
        FileUtils.rm_rf(bc.output_dir)
      end
    end

    trait :flat_dir_images do
      staging_location { 'spec/test_data/flat_dir_images' }
      content_metadata_creation { 'default' }
      content_structure { 'simple_image' }
      project_name { 'Flat_Dir_Images' }
    end

    trait :folder_manifest do
      staging_location { 'spec/test_data/obj_dirs_images' }
      content_metadata_creation { 'default' }
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
