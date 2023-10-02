# frozen_string_literal: true

# used by DiscoveryReport, this class validates an individual object's files
class ObjectFileValidator
  def initialize(object:, batch:)
    @object = object
    @batch = batch
    @errors = {}
    @counts = {}
  end

  attr_reader :errors, :counts

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/MethodLength
  def validate
    errors[:filename_no_extension] = filename_no_extension unless filename_no_extension.empty?
    @counts = {
      total_size: object.object_files.map(&:filesize).sum,
      mimetypes: Hash.new(0),
      filename_no_extension: filename_no_extension.count
    }
    object.object_files.each { |obj_file| counts[:mimetypes][obj_file.mimetype] += 1 } # number of files by mimetype
    empty_files = object.object_files.count { |obj_file| obj_file.filesize == 0 }
    errors[:empty_files] = empty_files if empty_files > 0
    errors.merge!(registration_check) # needs to come before manifest checks
    if using_file_manifest? # if we are using a file manifest, let's add how many files were found
      batch_id = object.druid.id
      if batch_id && file_manifest.manifest[batch_id]
        manifest_files = file_manifest.manifest[batch_id].fetch(:file_sets, []).flat_map { |_seq, val| val[:files] }
        counts[:files_in_manifest] = manifest_files.count
        relative_paths = object.object_files.map(&:relative_path) # Files found on disk
        all_paths = (cocina_filenames + relative_paths).uniq
        counts[:files_found] = (manifest_files.pluck(:filename) & relative_paths).count
        errors[:empty_manifest] = true unless counts[:files_in_manifest] > 0
        errors[:files_found_mismatch] = true unless counts[:files_in_manifest] == (manifest_files.pluck(:filename) & all_paths).count
      else
        errors[:missing_media_container_name_or_manifest] = true
      end
    end
    errors[:wrong_content_structure] = true if object_has_hierarchy? && batch.content_structure != 'file'
    errors[:empty_object] = true unless counts[:total_size] > 0
    errors[:missing_files] = true unless object_files_exist?
    errors[:dupes] = true unless object_filepaths_unique?
    self
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/MethodLength

  def as_json(*)
    to_h
  end

  def to_h
    { druid: druid.druid, errors: errors.compact, counts: }
  end

  # check to see if files within object has hierarchy (i.e. paths in filenames)
  def object_has_hierarchy?
    filepaths.any?(/\/+/)
  end

  private

  attr_reader :object, :batch

  delegate :druid, to: :object
  delegate :file_manifest, to: :batch

  # Checks filesystem for expected files
  def object_files_exist?
    return false if object.object_files.empty?

    object.object_files.map(&:path).all? { |path| File.readable?(path) }
  end

  # an array of all relative filepaths in the object
  def filepaths
    object.object_files.map(&:relative_path)
  end

  # check that all filenames are unique
  def object_filepaths_unique?
    filepaths.count == filepaths.uniq.count
  end

  def filename_no_extension
    @filename_no_extension = object.object_files.map(&:path).select { |path| File.extname(path).empty? }
  end

  # @param [DruidTools]
  # @return [Hash<Symbol => Boolean>] errors
  def registration_check
    object_client.find
    {}
  rescue Dor::Services::Client::NotFoundResponse
    { item_not_registered: true }
  rescue RuntimeError # HTTP timeout, network error, whatever
    { dor_connection_error: true }
  end

  def object_client
    Dor::Services::Client.object(druid.druid)
  end

  # @return [Boolean]
  def using_file_manifest?
    batch.using_file_manifest
  end

  def cocina_obj
    @cocina_obj = object_client.find
  end

  def cocina_filenames
    @cocina_filenames ||= cocina_obj.structural.contains.flat_map do |file_set|
      file_set.structural.contains.map(&:filename)
    end
  end
end
