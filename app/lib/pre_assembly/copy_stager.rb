# frozen_string_literal: true

module PreAssembly
  # "staged" files are copied to their destination; use LinkStager for large files
  class CopyStager
    def self.stage(source, destination)
      FileUtils.mkdir_p File.dirname(destination)
      FileUtils.cp_r source, destination
    end
  end
end
