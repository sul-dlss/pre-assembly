module PreAssembly
  class CopyStager
    def self.stage(source, destination)
      FileUtils.cp_r source, destination
    end
  end
end
