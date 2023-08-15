# frozen_string_literal: true

# @return [PreAssembly::Batch]
def batch_setup(proj)
  batch_context_from_hash(proj).batch
end

def hash_from_proj(proj)
  filename = "spec/fixtures/project_config_files/#{proj}.yaml"
  YAML.safe_load_file(filename)
end

def batch_context_from_hash(proj)
  hash = hash_from_proj(proj)
  cmc = hash['content_md_creation']['style']
  cmc += '_cm_style' if cmc == 'media'
  build(
    :batch_context,
    project_name: hash['project_name'],
    content_structure: hash['project_style']['content_structure'],
    staging_location: hash['staging_location'],
    content_metadata_creation: cmc,
    using_file_manifest: hash['using_file_manifest'],
    user: build(:user, sunet_id: 'Jdoe')
  )
end
