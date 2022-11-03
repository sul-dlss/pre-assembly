# frozen_string_literal: true

module PreAssembly
  # Represents the assembly structure on the filesystem,
  # Used by PreAssembly::DigitalObject
  class AssemblyDirectory
    def self.create(druid_id:, base_path: '')
      new(druid_id: druid_id, base_path: base_path).tap(&:create_object_directories)
    end

    def initialize(druid_id:, base_path: '')
      @druid_id = druid_id
      @base_path = base_path
    end

    # @return [String] the appropriate path for the file ('metadata' or 'content' will be last segment)
    def path_for(item_path)
      # these are the names of files that will be staged in the 'metadata' folder instead of the 'content' folder
      metadata_files = ['descMetadata.xml', 'contentMetadata.xml'].map(&:downcase)

      relative_path = item_path.delete_prefix(base_path)
      return File.join(content_dir, relative_path) unless metadata_files.include?(File.basename(item_path).downcase)

      Honeybadger.notify("I don't think we still stage descMetadata.xml or contentMetadata.xml anymore. Investigate this.")
      metadata_dir
    end

    # @return [String] the base druid tree folder for this object
    def druid_tree_dir
      @druid_tree_dir ||= DruidTools::Druid.new(druid_id, assembly_staging_dir).path
    end

    private

    attr_reader :druid_id, :base_path

    def create_object_directories
      FileUtils.mkdir_p druid_tree_dir unless File.directory?(druid_tree_dir)
      FileUtils.mkdir_p metadata_dir unless File.directory?(metadata_dir)
      FileUtils.mkdir_p content_dir unless File.directory?(content_dir)
    end

    def assembly_staging_dir
      Settings.assembly_staging_dir
    end

    # @return [String] the metadata subfolder
    def metadata_dir
      @metadata_dir ||= File.join(druid_tree_dir, 'metadata')
    end

    # @return [String] the content subfolder
    def content_dir
      @content_dir ||= File.join(druid_tree_dir, 'content')
    end
  end
end
