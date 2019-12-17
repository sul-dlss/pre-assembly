# frozen_string_literal: true

module PreAssembly
  class LinkStager
    def self.stage(source, destination)
      FileUtils.ln_s source, destination, force: true
    end
  end
end
