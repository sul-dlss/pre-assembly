module PreAssembly

  class Image

    include PreAssembly::Logging

    attr_accessor :file_name, :full_path, :provider_attr, :exp_md5

    def initialize(params = {})
      @file_name     = params[:file_name]
      @full_path     = params[:full_path]
      @provider_attr = params[:provider_attr]
      @exp_md5       = params[:exp_md5]
    end

    def valid?
      ai = Assembly::Image.new @full_path
      return ai.valid?
    end

  end

end
