# @param [#to_s] proj basename of YAML fixture file
# @return [PreAssembly::Bundle]
def bundle_setup(proj)
  PreAssembly::Bundle.new(context_from_proj(proj))
end

def context_from_proj(proj)
  filename = "spec/test_data/project_config_files/#{proj}.yaml"
  ps = YAML.load(File.read(filename))
  ps['config_filename'] = filename
  BundleContext.new(ps)
end
