# frozen_string_literal: true

class CsvImporter
  # load CSV allowing UTF-8 to pass through, deleting blank columns
  # @param [String] filename
  # @return [Array<ActiveSupport::HashWithIndifferentAccess>]
  # @raise if file missing/unreadable
  def self.parse_to_hash(filename)
    raise ArgumentError, 'CSV filename required' unless filename.present?
    raise ArgumentError, "Required file not found: #{filename}." unless File.readable?(filename)
    file_contents = IO.read(filename).encode('utf-8', replace: nil)
    file_contents.gsub(/\r\n?/, "\n") # coerce Windows line-endings
    file_contents = file_contents[1..-1] if file_contents[0].ord == 65_279 # purge Byte-order-mark
    csv = CSV.parse(file_contents, headers: true)
    csv.map { |row| row.to_hash.with_indifferent_access }
  end
end
