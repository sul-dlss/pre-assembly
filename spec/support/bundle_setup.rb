# @return [PreAssembly::Bundle]
def bundle_setup(proj)
  PreAssembly::Bundle.new(bundle_context_from_hash(proj))
end

def hash_from_proj(proj)
  filename = "spec/test_data/project_config_files/#{proj}.yaml"
  YAML.load(File.read(filename)).merge('config_filename' => filename)
end

def noko_doc(x)
  Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
end

def bundle_context_from_hash(proj)
  user = User.create(sunet_id: "Jdoe@stanford.edu")

  cmc = hash_from_proj(proj)["content_md_creation"]["style"]
  cmc = cmc + "_cm_style" if cmc == "smpl"

  bc = BundleContext.new(
    project_name: hash_from_proj(proj)["project_name"],
    content_structure: hash_from_proj(proj)["project_style"]["content_structure"],
    bundle_dir: hash_from_proj(proj)["bundle_dir"],
    staging_style_symlink: false,
    content_metadata_creation: cmc ,
    user: user
  )
  allow(bc).to receive(:progress_log_file).and_return(hash_from_proj(proj)["progress_log_file"])
  bc
end