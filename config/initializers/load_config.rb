ALLOWABLE_BUNDLE_DIRS = YAML.safe_load(ERB.new(File.read("#{Rails.root}/config/initializers/bundle_dir_roots.yml.erb")).result)[Rails.env]
ALLOWABLE_BUNDLE_DIRS = ALLOWABLE_BUNDLE_DIRS.map { |path| path.chomp('/') }
