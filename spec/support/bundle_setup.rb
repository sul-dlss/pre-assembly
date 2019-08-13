# @return [PreAssembly::Bundle]
def bundle_setup(proj)
  PreAssembly::Bundle.new(bundle_context_from_hash(proj))
end

def hash_from_proj(proj)
  filename = "spec/test_data/project_config_files/#{proj}.yaml"
  YAML.safe_load(File.read(filename)).merge('config_filename' => filename)
end

def noko_doc(x)
  Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
end

def bundle_context_from_hash(proj)
  hash = hash_from_proj(proj)
  cmc = hash['content_md_creation']['style']
  cmc += '_cm_style' if cmc == 'media'
  build(
    :bundle_context,
    project_name: hash['project_name'],
    content_structure: hash['project_style']['content_structure'],
    bundle_dir: hash['bundle_dir'],
    content_metadata_creation: cmc,
    user: build(:user, sunet_id: 'Jdoe')
  )
end
