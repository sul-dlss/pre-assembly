# frozen_string_literal: true

module PreAssembly
  # Represents the assembly structure on the filesystem
  class AssemblyDirectory
    def self.create(druid_id:)
      new(druid_id: druid_id).tap(&:create_object_directories)
    end

    def initialize(druid_id:)
      @druid_id = druid_id
    end

    def create_object_directories
      FileUtils.mkdir_p druid_tree_dir unless File.directory?(druid_tree_dir)
      FileUtils.mkdir_p metadata_dir unless File.directory?(metadata_dir)
      FileUtils.mkdir_p content_dir unless File.directory?(content_dir)
    end

    def path_for(item_path)
      # these are the names of files that will be staged in the 'metadata' folder instead of the 'content' folder
      metadata_files = ['descMetadata.xml', 'contentMetadata.xml'].map(&:downcase)

      metadata_files.include?(File.basename(item_path).downcase) ? metadata_dir : content_dir
    end

    # compute the base druid tree folder for this object
    def druid_tree_dir
      @druid_tree_dir ||= DruidTools::Druid.new(druid_id, assembly_staging_dir).path
    end

    def content_dir
      @content_dir ||= File.join(druid_tree_dir, 'content')
    end

    # the metadata subfolder
    def metadata_dir
      @metadata_dir ||= File.join(druid_tree_dir, 'metadata')
    end

    def technical_metadata_file
      File.join(metadata_dir, 'technicalMetadata.xml')
    end

    def content_metadata_file
      File.join(metadata_dir, 'contentMetadata.xml')
    end

    private

    attr_reader :druid_id

    def assembly_staging_dir
      Settings.assembly_staging_dir
    end
  end
end
