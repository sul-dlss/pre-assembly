FactoryBot.define do
  factory :bundle_context do
    bundle_dir { 'spec/test_data/smpl_multimedia' }
    content_metadata_creation { 'default' }
    content_structure { 'simple_image' }
    project_name { 'Test_Project' }
    staging_style_symlink { false }
    user
  end
end
