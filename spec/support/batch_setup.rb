# frozen_string_literal: true

# @return [PreAssembly::Batch]
def batch_setup(proj)
  PreAssembly::Batch.new(batch_context_from_hash(proj))
end

def hash_from_proj(proj)
  filename = "spec/test_data/project_config_files/#{proj}.yaml"
  YAML.safe_load(File.read(filename)).merge('config_filename' => filename)
end

def noko_doc(text_xml)
  Nokogiri.XML(text_xml) { |conf| conf.default_xml.noblanks }
end

# rubocop:disable Metrics/MethodLength
def batch_context_from_hash(proj)
  hash = hash_from_proj(proj)
  cmc = hash['content_md_creation']['style']
  cmc += '_cm_style' if cmc == 'media'
  build(
    :batch_context,
    project_name: hash['project_name'],
    content_structure: hash['project_style']['content_structure'],
    bundle_dir: hash['bundle_dir'],
    content_metadata_creation: cmc,
    using_file_manifest: hash['using_file_manifest'],
    user: build(:user, sunet_id: 'Jdoe')
  )
end
# rubocop:enable Metrics/MethodLength
