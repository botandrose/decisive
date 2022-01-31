require "rubyXL"

class XLSHasher < Struct.new(:path)
  def to_hash
    spreadsheet = RubyXL::Parser.parse(path)
    spreadsheet.worksheets.reduce({}) do |hash, worksheet|
      actual = []
      worksheet.each do |row|
        cells = row.cells.map do |cell|
          if cell.formula
            "=" + cell.formula.expression
          else
            cell.value
          end
        end
        actual << cells
      end
      hash.merge worksheet.sheet_name => actual
    end
  end
end

