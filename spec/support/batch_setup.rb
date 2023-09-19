# frozen_string_literal: true

# @return [PreAssembly::Batch]
def batch_setup(proj)
  project = project_from_hash(proj)
  job_run = build(:job_run, project:)
  job_run.batch
end

def hash_from_proj(proj)
  filename = "spec/fixtures/project_config_files/#{proj}.yaml"
  YAML.safe_load_file(filename)
end

def project_from_hash(proj)
  hash = hash_from_proj(proj)
  cmc = hash['processing_configuration']['style']
  cmc += '_cm_style' if cmc == 'media'
  build(
    :project,
    project_name: hash['project_name'],
    content_structure: hash['project_style']['content_structure'],
    staging_location: hash['staging_location'],
    processing_configuration: cmc,
    using_file_manifest: hash['using_file_manifest'],
    user: build(:user, sunet_id: 'Jdoe')
  )
end
