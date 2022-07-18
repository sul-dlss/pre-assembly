# frozen_string_literal: true

require 'csv'

# This looks for one of two varieties of file manifests that may be present in the staging location
class FileManifestFactory
  # an optional manifest that provides additional detail about the files contained in each object: only used for specific jobs
  FILE_MANIFEST_FILE_NAME = 'file_manifest.csv'

  def initialize(using_file_manifest, staging_location)
    @using_file_manifest = using_file_manifest
    @staging_location = staging_location
    @errors = []
  end

  def build
    return unless @using_file_manifest

    if file_manifest_with_rights?
      PreAssembly::FileManifestWithRights.new(csv: csv,
                                              staging_location: staging_location)
    else
      PreAssembly::FileManifest.new(csv: csv,
                                    staging_location: staging_location)
    end
  end

  def valid?
    @using_file_manifest && !File.exist?(path)
  end

  attr_reader :errors

  def path
    staging_location_with_path(FILE_MANIFEST_FILE_NAME)
  end

  private

  attr_reader :staging_location

  def file_manifest_with_rights?
    csv.headers.include?('rights_view')
  end

  def csv
    @csv ||= CSV.read(path, headers: true, encoding: 'bom|utf-8')
  end

  def staging_location_with_path(rel_path)
    File.join(staging_location, rel_path)
  end
end
