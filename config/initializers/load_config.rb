# frozen_string_literal: true

staging_location_roots = YAML.safe_load(ERB.new(Rails.root.join('config/initializers/staging_location_roots.yml.erb').read).result)[Rails.env]
ALLOWABLE_STAGING_LOCATIONS = staging_location_roots.map { |path| path.chomp('/') }
