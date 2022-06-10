# frozen_string_literal: true

module PreAssembly
  # Links are used to stage objects; useful for large files (e.g. media, WARC files)
  class LinkStager
    def self.stage(source, destination)
      FileUtils.ln_s source, destination, force: true
    end
  end
end
