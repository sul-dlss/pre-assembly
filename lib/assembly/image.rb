module Assembly

  class Image

    include Assembly::Logging

    attr_accessor :file_name, :full_path

    def initialize(params = {})
      @file_name = params[:file_name]
      @full_path = params[:full_path]
    end

  end

end
