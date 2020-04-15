# frozen_string_literal: true

# Finds the ObjectFiles for a digital object.
class ObjectFileFinder
  # @param [Array] stageable_items
  # @param [String] druid
  # @param [Bool] does the user indicate that these batch should preserve/publish/shelve all files
  # @param [Bool] does this druid have 'dark' access?
  def self.run(stageable_items:, druid:, dark:, all_files_public:)
    new(stageable_items: stageable_items, druid: druid, dark: dark, all_files_public: all_files_public).run
  end

  def initialize(stageable_items:, druid:, dark:, all_files_public:)
    @stageable_items = stageable_items
    @druid = druid
    @dark_obj = dark
    @all_files_public = all_files_public
  end

  # Returns a list of the ObjectFiles for a digital object.
  # @return [Array<PreAssembly::ObjectFile>]
  def run
    object_files = []
    Array(@stageable_items).each do |stageable|
      find_files_recursively(stageable).each do |file_path|
        object_files.push(new_object_file(stageable, file_path))
      end
    end
    object_files
  end

  # @param [String] stageable the object directory
  # @param [String] file_path the path to the file in the object directory
  # @param [Boolean] dark_obj - true if object access is dark, false otherwise
  # @return [PreAssembly::ObjectFile]
  def new_object_file(stageable, file_path)
    options = { relative_path: relative_path(base_dir(stageable), file_path) }
    if @dark_obj
      options[:file_attributes] = { preserve: 'yes', shelve: 'no', publish: 'no' }
    elsif @all_files_public
      options[:file_attributes] = { preserve: 'yes', shelve: 'yes', publish: 'yes' }
    end
    PreAssembly::ObjectFile.new(file_path, options)
  end

  # @return [String] path
  # @return [String] directory portion of the path before basename
  # @example Usage
  #   b.base_dir('BLAH/BLAH/foo/bar.txt')
  #   => 'BLAH/BLAH/foo'
  def base_dir(path)
    bd = File.dirname(path)
    return bd unless bd == '.'
    raise ArgumentError, "Bad arg to get_base_dir(#{path.inspect})"
  end

  # @return [String] base
  # @return [String] path
  # @return [String] portion of the path after the base, without trailing slashes (if directory)
  # @example Usage
  #   b.relative_path('BLAH/BLAH', 'BLAH/BLAH/foo/bar.txt'
  #   => 'foo/bar.txt'
  #   b.relative_path('BLAH/BLAH', 'BLAH/BLAH/foo///'
  #   => 'foo'
  def relative_path(base, path)
    Pathname.new(path).relative_path_from(Pathname.new(base)).cleanpath.to_s
  end

  # @param [String] path the path to a file or dir.
  # @return [Array<String>} all files (but not dirs) contained in the path, recursively.
  def find_files_recursively(path)
    patterns = [path, File.join(path, '**', '*')]
    Dir.glob(patterns).reject { |f| File.directory? f }.sort
  end
end
