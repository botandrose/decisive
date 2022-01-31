require "roo"

class XLSHasher < Struct.new(:path)
  def to_hash
    spreadsheet = Roo::Spreadsheet.open(path, extension: :xlsx)
    spreadsheet.sheets.reduce({}) do |hash, name|
      actual = []
      spreadsheet.sheet(name).each { |row| actual << row }
      hash.merge name => actual
    end
  end
end

