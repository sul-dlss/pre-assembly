# Previously a single untested 200-line method from ./lib/pre_assembly/reporting.rb
# Takes a Bundle, enumerates report data via #each_row
class DiscoveryReport
  attr_reader :bundle, :start_time

  delegate :bundle_dir, :content_md_creation, :manifest, :object_discovery, :project_style, to: :bundle
  delegate :checksums_file, :confirm_checksums, :error_count, :object_filenames_unique?, to: :bundle

  # @param [PreAssembly::Bundle] bundle
  def initialize(bundle)
    raise ArgumentError unless bundle.is_a?(PreAssembly::Bundle)
    @start_time = Time.now
    @bundle = bundle
    bundle.discover_objects
    bundle.process_manifest
  end

  # @return [Enumerable<Hash<Symbol => Object>>]
  # @yield [Hash<Symbol => Object>] data structure about a DigitalObject
  def each_row
    return enum_for(:each_row) unless block_given?
    bundle.objects_to_process.each { |dobj| yield process_dobj(dobj) }
  end

  # @param [PreAssembly::DigitalObject]
  # @return [Hash<Symbol => Object>]
  def process_dobj(dobj)
    errors = {}
    counts = {
      total_size: dobj.object_files.map(&:filesize).sum,
      mimetypes: Hash.new(0)
    }
    dobj.object_files.each { |obj| counts[:mimetypes][obj.mimetype] += 1 } # number of files by mimetype
    errors[:filename_no_extension] = true if dobj.object_files.any? { |obj| File.extname(obj.path).empty? }
    counts[:empty_files] = dobj.object_files.count { |obj| obj.filesize == 0 }
    if using_smpl_manifest? # if we are using a SMPL manifest, let's add how many files were found
      bundle_id = File.basename(dobj.unadjusted_container)
      cm_files = smpl.manifest[bundle_id].fetch(:files, [])
      counts[:files_in_manifest] = cm_files.count
      relative_paths = dobj.object_files.map(&:relative_path)
      counts[:files_found] = (cm_files.map(&:filename) & relative_paths).count
      errors[:empty_manifest] = true unless counts[:files_in_manifest] > 0
      errors[:files_found_mismatch] = true unless counts[:files_in_manifest] == counts[:files_found]
    end

    errors[:empty_files] = true if counts[:empty_files] > 0
    errors[:empty_object] = true if counts[:total_size] > 0
    errors[:missing_files] = true unless dobj.object_files_exist?
    errors[:checksum_mismatch] = true unless !checksums_file || confirm_checksums(dobj)
    errors[:dupes] = true unless object_filenames_unique?(dobj)
    counts[:source_ids][dobj.source_id] += 1
    errors.merge!(registration_check(dobj.determine_druid))
    if using_manifest? # check global uniqueness
      errors[:source_id_dup] = true if dobj.source_id.any? { |id| Dor::SearchService.query_by_id(id) }
    end
    return { errors: errors, counts: counts }
  end

  # @param [String] druid
  # @return [Hash<Symbol => Boolean>] errors
  def registration_check(druid)
    begin
      obj = Dor::Item.find(druid)
    rescue ActiveFedora::ObjectNotFoundError
      return { item_not_registered: true }
    end
    return { apo_empty: true } unless obj.admin_policy_object
    {}
  rescue ActiveFedora::ObjectNotFoundError
    return { apo_not_registered: true }
  end

  # @return [String] primitive version
  def header
    fields = ['Object Container', 'Number of Items', 'Files with no ext', 'Files with 0 Size', 'Total Size', 'Files Readable']
    fields.concat ['Label', 'Source ID'] if using_manifest?
    fields.concat ['Num Files in CM Manifest', 'All CM files found'] if using_smpl_manifest?
    fields << 'Checksums' if checksums_file
    fields.concat ['Duplicate Filenames?', 'DRUID', 'Registered?', 'APO exists?']
    fields << 'SourceID unique in DOR?' if using_manifest?
    fields.join(' , ')
  end

  # For use by template
  def skipped_files
    files = ['Thumbs.db', '.DS_Store'] # if these files are in the bundle directory but not in the manifest, they will be ignorned and not reported as missing
    files << File.basename(content_md_creation[:smpl_manifest]) if using_smpl_manifest?
    files << File.basename(manifest) if using_manifest?
    files << File.basename(checksums_file) if checksums_file
    files
  end

  # @return [Boolean]
  def using_manifest?
    manifest && object_discovery[:use_manifest]
  end

  # @return [Boolean]
  def using_smpl_manifest?
    content_md_creation[:style] == :smpl && File.exist?(File.join(bundle_dir, content_md_creation[:smpl_manifest]))
  end

  # @return [PreAssembly::Smpl]
  def smpl
    @smpl ||= PreAssembly::Smpl.new(csv_filename: content_md_creation[:smpl_manifest], bundle_dir: bundle_dir)
  end

end
