module PreAssembly

  class ObjectFile

    include PreAssembly::Logging

    attr_accessor :path

    def initialize(params = {})
      @path = params[:path]
    end

  end

end
