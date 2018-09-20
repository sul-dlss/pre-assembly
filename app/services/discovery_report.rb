# Previously a single untested 200-line method from ./lib/pre_assembly/reporting.rb
# Takes a Bundle, enumerates report data via #each_row
class DiscoveryReport
  attr_reader :bundle, :start_time, :summary

  delegate :bundle_dir, :content_md_creation, :manifest, :project_style, to: :bundle
  delegate :object_filenames_unique?, to: :bundle

  # @param [PreAssembly::Bundle] bundle
  def initialize(bundle)
    raise ArgumentError unless bundle.is_a?(PreAssembly::Bundle)
    @start_time = Time.now
    @bundle = bundle
    @summary = { objects_with_error: 0, mimetypes: Hash.new(0), start_time: start_time.to_s, total_size: 0 }
  end

  # @return [Enumerable<Hash<Symbol => Object>>]
  # @yield [Hash<Symbol => Object>] data structure about a DigitalObject
  def each_row
    return enum_for(:each_row) unless block_given?
    bundle.objects_to_process.each do |dobj|
      row = process_dobj(dobj)
      summary[:total_size] += row[:counts][:total_size]
      summary[:objects_with_error] += 1 unless row[:errors].empty?
      row[:counts][:mimetypes].each { |k, v| summary[:mimetypes][k] += v }
      yield row
    end
  end

  # @param [PreAssembly::DigitalObject]
  # @return [Hash<Symbol => Object>]
  def process_dobj(dobj)
    errors = {}
    filename_no_extension = dobj.object_files.map(&:path).select { |path| File.extname(path).empty? }
    errors[:filename_no_extension] = filename_no_extension unless filename_no_extension.empty?
    counts = {
      total_size: dobj.object_files.map(&:filesize).sum,
      mimetypes: Hash.new(0),
      filename_no_extension: filename_no_extension.count,
    }
    dobj.object_files.each { |obj| counts[:mimetypes][obj.mimetype] += 1 } # number of files by mimetype
    empty_files = dobj.object_files.count { |obj| obj.filesize == 0 }
    errors[:empty_files] = empty_files if empty_files > 0

    if using_smpl_manifest? # if we are using a SMPL manifest, let's add how many files were found
      bundle_id = File.basename(dobj.unadjusted_container)
      cm_files = smpl.manifest[bundle_id].fetch(:files, [])
      counts[:files_in_manifest] = cm_files.count
      relative_paths = dobj.object_files.map(&:relative_path)
      counts[:files_found] = (cm_files.map(&:filename) & relative_paths).count
      errors[:empty_manifest] = true unless counts[:files_in_manifest] > 0
      errors[:files_found_mismatch] = true unless counts[:files_in_manifest] == counts[:files_found]
    end

    errors[:empty_object] = true unless counts[:total_size] > 0
    errors[:missing_files] = true unless dobj.object_files_exist?
    errors[:dupes] = true unless object_filenames_unique?(dobj)
    errors.merge!(registration_check(dobj.druid))
    { druid: dobj.druid.druid, errors: errors.compact, counts: counts }
  end

  # @param [String] druid
  # @return [Hash<Symbol => Boolean>] errors
  def registration_check(druid)
    begin
      obj = Dor::Item.find(druid.druid)
    rescue ActiveFedora::ObjectNotFoundError
      return { item_not_registered: true }
    end
    begin
      return { apo_empty: true } unless obj.admin_policy_object
      {}
    rescue ActiveFedora::ObjectNotFoundError
      return { apo_not_registered: true }
    end
  rescue RuntimeError # HTTP timeout, network error, whatever
    return { dor_connection_error: true }
  end

  # For use by template
  def skipped_files
    files = ['Thumbs.db', '.DS_Store', manifest] # if these files are in the bundle directory but not in the manifest, they will be ignorned and not reported as missing
    files << File.basename(content_md_creation[:smpl_manifest]) if using_smpl_manifest?
    files
  end

  # @return [Boolean]
  def using_smpl_manifest?
    content_md_creation == :smpl && File.exist?(File.join(bundle_dir, bundle.bundle_context.smpl_manifest))
  end

  # @return [PreAssembly::Smpl]
  def smpl
    @smpl ||= PreAssembly::Smpl.new(csv_filename: content_md_creation[:smpl_manifest], bundle_dir: bundle_dir)
  end
end
