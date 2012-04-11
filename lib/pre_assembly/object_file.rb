module PreAssembly

  class ObjectFile

    include PreAssembly::Logging

    attr_accessor :path, :checksum

    def initialize(params = {})
      @path     = params[:path]
      @checksum = params[:checksum]
    end

  end

end
