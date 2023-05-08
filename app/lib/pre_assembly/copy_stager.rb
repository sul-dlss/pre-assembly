# frozen_string_literal: true

module PreAssembly
  # "staged" files are copied to their destination; use LinkStager for large files
  class CopyStager
    def self.stage(source, destination)
      FileUtils.mkdir_p File.dirname(destination)
      FileUtils.cp_r source, destination
      recursively_chmod_based_on_type!(destination)
    end

    def self.recursively_chmod_based_on_type!(path)
      unless File.directory?(path)
        FileUtils.chmod 0o0664, path
        return
      end

      FileUtils.chmod 0o0775, path

      Dir["#{path}/*"].each do |f|
        recursively_chmod_based_on_type!(f)
      end
    end
  end
end
