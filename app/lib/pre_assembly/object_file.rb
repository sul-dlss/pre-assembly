class PreAssembly::ObjectFile < Assembly::ObjectFile
  attr_accessor(
    :relative_path,
    :exclude_from_content,
    :checksum
  )

  def initialize(params = {})
    @path                 = params[:path]
    @relative_path        = params[:relative_path]
    self.checksum         = params[:checksum]
    @exclude_from_content = params[:exclude_from_content]
  end

  def checksum
    @checksum
  end

  def checksum=(value)
    @checksum = value
    self.provider_md5 = value # this is an attribute of the Assembly::ObjectFile class
  end

  def <=>(other)
    @relative_path <=> other.relative_path
  end
end
