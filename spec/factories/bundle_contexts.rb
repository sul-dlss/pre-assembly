# frozen_string_literal: true

FactoryBot.define do
  factory :bundle_context do
    bundle_dir { 'spec/test_data/multimedia' }
    content_metadata_creation { 'default' }
    content_structure { 'simple_image' }
    project_name { 'Test_Project' }
    staging_style_symlink { false }
    user

    # some tests require BCs with clean output_dir
    factory :bundle_context_with_deleted_output_dir do
      after(:build) do |bc|
        Dir.delete(bc.output_dir) if Dir.exist?(bc.output_dir)
      end
    end

    trait :flat_dir_images do
      bundle_dir { 'spec/test_data/flat_dir_images' }
      content_metadata_creation { 'default' }
      content_structure { 'simple_image' }
      project_name { 'Flat_Dir_Images' }
    end

    trait :folder_manifest do
      bundle_dir { 'spec/test_data/obj_dirs_images' }
      content_metadata_creation { 'default' }
      content_structure { 'simple_image' }
      project_name { 'FolderManifest' }
    end

    trait :public_files do
      all_files_public { true }
    end
  end
end
