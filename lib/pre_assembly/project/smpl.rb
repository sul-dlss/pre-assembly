module PreAssembly
  module Project
    module Smpl
      # the name of this method must be "create_content_metadata_xml_#{content_md_creation--style}", as defined in the YAML configuration
      def create_content_metadata_xml_smpl
        @smpl_manifest.generate_cm(@druid.id)
      end
    end # SMPL module
  end # project module
end # pre-assembly module
