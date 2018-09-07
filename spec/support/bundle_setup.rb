# @param [#to_s] proj basename of YAML fixture file
# @return [PreAssembly::Bundle]
def bundle_setup(proj)
  PreAssembly::Bundle.new(context_from_proj(proj))
end

def hash_from_proj(proj)
  filename = "spec/test_data/project_config_files/#{proj}.yaml"
  YAML.load(File.read(filename)).merge('config_filename' => filename)
end

def context_from_proj(proj)
  BundleContextTemporary.new(hash_from_proj(proj))
end

def noko_doc(x)
  Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
end
