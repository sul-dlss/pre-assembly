require 'csv-mapper'

module PreAssembly

  class BundleUsageError < StandardError
    # Exception class used to pass usage error messages back to
    # users of the bin/pre-assemble script.
  end

  class Bundle
    include PreAssembly::Logging
    include CsvMapper

    attr_accessor(
      :bundle_dir,
      :manifest,
      :descriptive_metadata_template,
      :desc_metadata_xml_template,
      :checksums_file,
      :project_name,
      :apo_druid_id,
      :set_druid_id,
      :staging_dir,
      :cleanup,
      :limit_n,
      :uniqify_source_ids,
      :show_progress,
      :project_style,
      :exp_checksums,
      :publish,
      :shelve,
      :preserve,
      :digital_objects,
      :stager
    )

    def initialize(params = {})
      validate_usage params if params[:validate_usage]

      conf                = Dor::Config.pre_assembly
      @bundle_dir         = params[:bundle_dir]     || ''
      @manifest           = params[:manifest]       || conf.manifest_file_name
      @descriptive_metadata_template = params[:descriptive_metadata_template] || conf.descriptive_metadata_template
      @checksums_file     = params[:checksums_file] || conf.checksums_file_name
      @project_name       = params[:project_name]
      @apo_druid_id       = params[:apo_druid_id]
      @set_druid_id       = params[:set_druid_id]
      @publish            = params[:publish]  || conf.publish
      @shelve             = params[:shelve]   || conf.shelve
      @preserve           = params[:preserve] || conf.preserve
      @staging_dir        = params[:staging_dir]
      @cleanup            = params[:cleanup]
      @limit_n            = params[:limit_n]
      @uniqify_source_ids = params[:uniqify_source_ids]
      @show_progress      = params[:show_progress]
      @project_style      = params[:project_style] || :NONE
      setup
    end

    def setup
      @manifest        = full_path_in_bundle_dir @manifest
      @checksums_file  = full_path_in_bundle_dir @checksums_file
      @descriptive_metadata_template  = full_path_in_bundle_dir @descriptive_metadata_template
      @desc_metadata_xml_template=File.open( @descriptive_metadata_template, "rb").read if file_exists @descriptive_metadata_template
      @exp_checksums   = {}
      @digital_objects = []
      @stager          = lambda { |f,d| FileUtils.copy f, d }
      @project_style   = @project_style.to_sym
    end

    def required_dirs
      [:bundle_dir, :staging_dir]
    end

    def required_params(project_style)
      [
        :bundle_dir,
        :staging_dir,
        :manifest,
        :checksums_file,
        :project_name,
        :apo_druid_id,
        :set_druid_id,
      ]
    end

    def validate_usage(params)
      # Check for required parameters and directories.
      project_style = params[:project_style]
      required_params(project_style).each do |p|
        raise BundleUsageError, "Missing parameter: #{p.to_s}." unless params.has_key? p
      end

      required_dirs.each do |p|
        d = params[p]
        raise BundleUsageError, "Directory not found: #{d}." unless File.directory? d
      end
    end

    def run_pre_assembly
      log ""
      log "run_pre_assembly(#{run_log_msg})"
      if @project_style == :revs
        check_for_required_files
        load_exp_checksums
        load_manifest
        validate_images
        process_digital_objects
        delete_digital_objects if @cleanup
      else
        # TODO: run_pre_assembly: add missing Rumsey steps.

        discover_images

        # check_for_required_files
        # Do not call delete_digital_objects().
      end
    end

    def discover_images
      druid_subdirs = Dir["#{@bundle_dir}/*"].select { |d| File.directory? d }
      druid_subdirs.each do |subdir|
        druid = File.basename subdir
        files = Dir.new(subdir).entries.reject { |e| e == '.' or e == '..'  }
        raise "Unexpected files in druid subdirectory: #{subdir}" unless files.size == 2
        # p files

        image     = File.basename Dir["#{subdir}/*.tif"].first
        image     = "#{druid}/#{image}"
        desc_meta = "#{druid}/descMetadata.xml"
        # p [druid, image, desc_meta]
      end
    end

    def run_log_msg
      log_params = {
        :project_style => @project_style,
        :bundle_dir    => @bundle_dir,
        :staging_dir   => @staging_dir,
        :environment   => ENV['ROBOT_ENVIRONMENT'],
      }
      log_params.map { |k,v| "#{k}='#{v}'"  }.join(', ')
    end

    def full_path_in_bundle_dir(file)
      File.join @bundle_dir, file
    end

    def check_for_required_files
      log "check_for_required_files()"
      required_files.each do |f|
        next if file_exists f
        raise IOError, "Required file or directory not found: #{f}\n"
      end
    end

    def required_files
      rfs = [@staging_dir]
      rfs.push(@manifest, @checksums_file) if @project_style == :revs
      rfs
    end

    def file_exists(file)
      File.exists? file
    end

    def load_exp_checksums
      # Read checksums_file, using its content to populate a hash of expected checksums.
      log "load_exp_checksums()"
      checksum_regex = %r{^MD5 \((.+)\) = (\w{32})$}
      read_exp_checksums.scan(checksum_regex).each { |file_name, md5|
        @exp_checksums[file_name] = md5
      }
    end

    def read_exp_checksums
      IO.read @checksums_file
    end

    def source_id_suffix
      # Used during development to append a timestamp to source IDs.
      @uniqify_source_ids ? Time.now.strftime('_%s') : ''
    end

    def load_manifest
      # Read manifest and initialize digital objects.
      log "load_manifest()"
      parse_manifest.each do |r|
        # Create digital object.
        dobj_params = {
          :project_name => @project_name,
          :apo_druid_id => @apo_druid_id,
          :set_druid_id => @set_druid_id,
          :desc_metadata_xml_template => @desc_metadata_xml_template,
          :publish      => @publish,
          :shelve       => @shelve,
          :preserve     => @preserve,
          :source_id    => r.sourceid + source_id_suffix,
          :label        => r.label,
        }
        dobj = DigitalObject::new dobj_params

        # Add the image to the object.
        f = r.filename
        dobj.add_image(
          :file_name     => f,
          :full_path     => full_path_in_bundle_dir(f),
          :provider_attr => Hash[r.each_pair.to_a],
          :exp_md5       => @exp_checksums[f]
        )
        @digital_objects.push dobj

        # Bail if user asked to process a limited N of objects.
        break if @limit_n and @digital_objects.size >= @limit_n
      end
    end

    def parse_manifest
      return import(@manifest) { read_attributes_from_file }
    end

    def validate_images
      log "validate_images()"
      @digital_objects.each do |dobj|
        dobj.images.each do |img|
          next if img.valid?
          msg = "Image validation failed: #{img.full_path} #{dobj.source_id.inspect}"
          raise msg
        end
      end
    end

    def process_digital_objects
      log "process_digital_objects()"
      @digital_objects.each do |dobj|
        dobj.pre_assemble(@stager, @staging_dir)
        puts dobj.druid.druid if @show_progress 
      end
    end

    def delete_digital_objects
      # During development, delete objects the we register.
      log "delete_digital_objects()"
      @digital_objects.each { |dobj| dobj.unregister }
    end

  end

end
