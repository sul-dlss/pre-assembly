# frozen_string_literal: true

module PreAssembly
  class ObjectFile < Assembly::ObjectFile
    include ActiveModel::AttributeMethods
    attr_accessor :exclude_from_content

    alias_attribute :checksum, :provider_md5

    # @param [String] path full path
    # @param [Hash<Symbol => Object>] params
    # @see Assembly::ObjectFile, Assembly::ObjectFileable
    def initialize(path, params = {})
      super
      @provider_md5 ||= params[:checksum]
      @exclude_from_content = params[:exclude_from_content] || false
    end

    # This is a bit of a lie.  ObjectFiles with the same relative_path but different checksums
    # are clearly not representing the same thing.
    def <=>(other)
      relative_path <=> other.relative_path
    end
  end
end
