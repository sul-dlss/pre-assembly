# frozen_string_literal: true

class ObjectFileValidator
  def initialize(object:, bundle:)
    @object = object
    @bundle = bundle
    @errors = {}
    @counts = {}
  end

  attr_reader :errors, :counts

  def validate
    errors[:filename_no_extension] = filename_no_extension unless filename_no_extension.empty?
    @counts = {
      total_size: object.object_files.map(&:filesize).sum,
      mimetypes: Hash.new(0),
      filename_no_extension: filename_no_extension.count
    }
    object.object_files.each { |obj| counts[:mimetypes][obj.mimetype] += 1 } # number of files by mimetype
    empty_files = object.object_files.count { |obj| obj.filesize == 0 }
    errors[:empty_files] = empty_files if empty_files > 0

    if using_media_manifest? # if we are using a media manifest, let's add how many files were found
      bundle_id = File.basename(object.container)
      if bundle_id && media.manifest[bundle_id]
        cm_files = media.manifest[bundle_id].fetch(:files, [])
        counts[:files_in_manifest] = cm_files.count
        relative_paths = object.object_files.map(&:relative_path)
        counts[:files_found] = (cm_files.pluck(:filename) & relative_paths).count
        errors[:empty_manifest] = true unless counts[:files_in_manifest] > 0
        errors[:files_found_mismatch] = true unless counts[:files_in_manifest] == counts[:files_found]
      else
        errors[:missing_media_container_name_or_manifest] = true
      end
    end

    errors[:empty_object] = true unless counts[:total_size] > 0
    errors[:missing_files] = true unless object_files_exist?
    errors[:dupes] = true unless bundle.object_filenames_unique?(object)
    errors.merge!(registration_check)
    self
  end

  def as_json(*)
    { druid: druid.druid, errors: errors.compact, counts: counts }
  end

  private

  attr_reader :object, :bundle
  delegate :druid, to: :object

  # Checks filesystem for expected files
  def object_files_exist?
    return false if object.object_files.empty?
    object.object_files.map(&:path).all? { |path| File.readable?(path) }
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
    @object_client ||= Dor::Services::Client.object(druid.druid)
  end

  # @return [PreAssembly::Media]
  def media
    @media ||= PreAssembly::Media.new(csv_filename: bundle.bundle_context.media_manifest,
                                      bundle_dir: bundle.bundle_dir)
  end

  # @return [Boolean]
  def using_media_manifest?
    bundle.content_md_creation == 'media_cm_style' &&
      File.exist?(File.join(bundle.bundle_dir, bundle.bundle_context.media_manifest))
  end
end
