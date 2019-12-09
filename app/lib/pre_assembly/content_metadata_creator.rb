module PreAssembly
  class ContentMetadataCreator
    def initialize(druid_id:, content_md_creation:, object_files:, content_md_creation_style:, media_manifest:)
      @druid_id = druid_id
      @content_md_creation = content_md_creation
      @object_files = object_files
      @content_md_creation_style = content_md_creation_style
      @media_manifest = media_manifest
    end

    # Invoke the contentMetadata creation method used by the project
    def create
      return media_manifest.generate_cm(druid_id) if content_md_creation == 'media_cm_style'

      # otherwise use the content metadata generation gem
      Assembly::ContentMetadata.create_content_metadata(druid: druid_id,
                                                        objects: content_object_files,
                                                        add_exif: false,
                                                        bundle: content_md_creation.to_sym,
                                                        style: content_md_creation_style)
    end

    private

    attr_reader :druid_id, :content_md_creation, :object_files, :content_md_creation_style, :media_manifest

    # Object files that should be included in content metadata.
    def content_object_files
      object_files.reject(&:exclude_from_content).sort
    end
  end
end