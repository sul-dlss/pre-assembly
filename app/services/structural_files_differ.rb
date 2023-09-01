# frozen_string_literal: true

# Compares an existing and a new Cocina::Models::DROStructural to determine:
#  - added files: Cocina::Models::File that are in the new structural but not in the existing structural
#  - deleted files: Cocina::Models::File that are in the existing structural but not in the new structural
#  - updated files: Cocina::Models::File that are in the existing structural and the file found in the stage location
class StructuralFilesDiffer
  # @param [Cocina::Models::DROStructural] existing_structural - structural metadata for the existing object in SDR
  # @param [Cocina::Models::DROStructural] new_structural - structural metadata for the new object based on file manifest
  # @param [String] staging_location - the location where the files for the batch are staged
  # @param [String] druid - the druid of the object, which corresponds to the directory name in the staging location
  # @return [Hash] hash containing arrays of added, deleted, and updated files
  def self.diff(existing_structural:, new_structural:, staging_location:, druid:)
    new(existing_structural:,
        new_structural:,
        staging_location:,
        druid:).diff
  end

  def initialize(existing_structural:, new_structural:, staging_location:, druid:)
    @existing_structural = existing_structural
    @new_structural = new_structural
    @staging_location = staging_location
    @druid = druid.delete_prefix('druid:')
  end

  def diff
    {
      added_files:,
      deleted_files:,
      updated_files:
    }
  end

  # @return [Array<String>] filenames of files that are in the new structural but not in the existing structural
  def added_files
    new_files - existing_files
  end

  # @return [Array<String>] filenames of files that are in the existing structural but not in the new structural
  def deleted_files
    existing_files - new_files
  end

  # @return [Array<String>] filenames of files that are in the existing structural and the file found in the stage location
  def updated_files
    existing_files.select do |existing_file|
      File.exist?(File.join(staging_location, druid, existing_file))
    end
  end

  private

  attr_reader :existing_structural, :new_structural, :staging_location, :druid

  def existing_files
    @existing_files ||= files_for(existing_structural)
  end

  def new_files
    @new_files ||= files_for(new_structural)
  end

  def files_for(structural)
    structural.contains.flat_map do |file_set|
      file_set.structural.contains.map(&:filename)
    end
  end
end
