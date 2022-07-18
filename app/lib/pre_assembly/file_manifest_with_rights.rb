# frozen_string_literal: true

module PreAssembly
  # This handles the "Argo style" file manifest that has columns for the file rights
  class FileManifestWithRights < FileManifest
    def folder(row)
      row['druid']
    end

    def file_set_label(row)
      row['resource_label']
    end

    def file_label(row)
      row['file_label']
    end

    # @param [HashWithIndifferentAccess] row
    # @return [Hash<Symbol,String>] The properties necessary to build a file.
    def file_properties_from_row(row, folder_name)
      super.merge(access: {
        view: row['rights_view'],
        download: row['rights_download'],
        location: row['rights_location']
      }.compact)
    end
  end
end
