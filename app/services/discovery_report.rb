# May not be pretty, but you should see where this logic came from.
class DiscoveryReport
  attr_accessor :bundle
  attr_accessor :confirm_checksums, :check_sourceids, :no_check_reg, :show_other, :show_smpl_cm, :show_staged # user params
  attr_accessor :start_time

  delegate :bundle_dir, :checksums_file, :content_md_creation, :manifest, :object_discovery, :project_style, to: :bundle
  delegate :error_count, :report_error_message, to: :bundle

  # @param [PreAssembly::Bundle] bundle
  # @param [Hash<Symbol => Boolean>] params
  def initialize(bundle, params = {})
    raise ArgumentError unless bundle.is_a?(PreAssembly::Bundle)
    self.bundle = bundle
    [:confirm_checksums, :check_sourceids, :no_check_reg, :show_other, :show_smpl_cm, :show_staged].each do |attrib|
      self.public_send("#{attrib}=", params[attrib])
    end
  end

  def run
    bundle.discover_objects
    bundle.process_manifest
    objects_to_process.each { |dobj| per_dobj(dobj) }
  end

  def smpl_manifest
    @smpl_manifest ||= PreAssembly::Smpl.new(csv_filename: content_md_creation[:smpl_manifest], bundle_dir: bundle_dir)
  end

  # @return [Hash<Symbol => Object>]
  def per_dobj(dobj)
    bundle_id = File.basename(dobj.unadjusted_container)
    errors = {}
    counts = Hash.new(Hash.new(0))
    counts[:total_size] = dobj.object_files.map(&:filesize).sum
    dobj.object_files.each { |obj| counts[:mimetypes][obj.mimetype] += 1 } # number of files by mimetype
    filenames_with_no_extension = dobj.object_files.any? { |obj| File.extname(obj.path).empty? }
    counts[:empty_files] = dobj.object_files.count { |obj| obj.filesize == 0 }
    if using_smpl_manifest? # if we are using a SMPL manifest, let's add how many files were found
      cm_files = smpl_manifest.manifest[bundle_id].fetch(:files, [])
      counts[:files_in_manifest] = cm_files.count
      relative_paths = dobj.object_files.map(&:relative_path)
      counts[:files_found] = (cm_files.map(&:filename) & relative_paths).count
      errors[:empty_manifest] = true unless counts[:files_in_manifest] > 0
      errors[:files_found_mismatch] = true unless counts[:files_in_manifest] == counts[:files_found]
    end

    errors[:empty_files] = true if counts[:empty_files] > 0
    errors[:empty_object] = true if counts[:total_size] > 0
    errors[:missing_files] = true unless dobj.object_files_exist?
    errors[:checksum_mismatch] = true unless !confirming_checksums? || confirm_checksums(dobj)
    errors[:dupes] = true unless object_filenames_unique?(dobj)
    counts[:source_ids][dobj.source_id] += 1

    if confirming_registration? # objects should already be registered, let's confirm that
      dobj.determine_druid
      druid = dobj.pid.include?('druid') ? dobj.pid : "druid:#{dobj.pid}"
      begin
        obj = Dor::Item.find(druid)
      rescue ActiveFedora::ObjectNotFoundError
        errors[:item_not_registered] = true
      end
      begin
        obj.admin_policy_object || errors[:apo_empty] = true
      rescue ActiveFedora::ObjectNotFoundError
        errors[:apo_not_registered] = true
      end
    end

    if checking_sourceids? # check global uniqueness
      errors[:source_id_dup] = true if dobj.source_id.any? { |id| Dor::SearchService.query_by_id(id) }
    end
  end

  # @return [String] primitive version
  def header
    fields = ['Object Container', 'Number of Items', 'Files with no ext', 'Files with 0 Size', 'Total Size', 'Files Readable']
    fields.concat ['Label', 'Source ID'] if using_manifest?
    fields.concat ['Num Files in CM Manifest', 'All CM files found'] if using_smpl_manifest?
    fields << 'Checksums' if confirming_checksums?
    fields << 'Duplicate Filenames?'
    fields.concat ['DRUID', 'Registered?', 'APO exists?']  if confirming_registration?
    fields << 'SourceID unique in DOR?' if checking_sourceids?
    fields.join(' , ')
  end

  def skipped_files
    files = ['Thumbs.db', '.DS_Store'] # if these files are in the bundle directory but not in the manifest, they will be ignorned and not reported as missing
    files << File.basename(content_md_creation[:smpl_manifest]) if using_smpl_manifest?
    files << File.basename(manifest) if using_manifest?
    files << File.basename(checksums_file) if checksums_file
    files
  end

  # Interrogative methods returning Boolean

  def barcode_project?
    project_style[:get_druid_from] == :container_barcode
  end

  def checking_sourceids?
    check_sourceids && using_manifest
  end

  def confirming_checksums?
    checksums_file && confirm_checksums
  end

  def confirming_registration?
    !no_check_reg # && !project_style[:should_register]
  end

  def show_smpl_cm?
    show_smpl_cm && using_smpl_manifest?
  end

  def using_manifest?
    manifest && object_discovery[:use_manifest]
  end

  def using_smpl_manifest?
    content_md_creation[:style] == :smpl && File.exist?(File.join(bundle_dir, content_md_creation[:smpl_manifest]))
  end
end
