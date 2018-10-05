bundle_dir_roots = YAML.safe_load(ERB.new(File.read("#{Rails.root}/config/initializers/bundle_dir_roots.yml.erb")).result)[Rails.env]
ALLOWABLE_BUNDLE_DIRS = bundle_dir_roots.map { |path| path.chomp('/') }
