ALLOWABLE_BUNDLE_DIRS = YAML.safe_load(ERB.new(File.read("#{Rails.root}/config/settings/bundle_dir_roots.yml.erb")).result)[Rails.env]
