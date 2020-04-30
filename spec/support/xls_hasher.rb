require "simple-spreadsheet"

class XLSHasher < Struct.new(:path)
  def to_hash
    spreadsheet = SimpleSpreadsheet::Workbook.read(path)
    spreadsheet.sheets.reduce({}) do |hash, worksheet|
      actual = []
      spreadsheet.foreach(worksheet) { |row| actual << row }
      hash.merge worksheet => actual
    end
  end
end

# UGH default implementation skips blank cells WTF WTF
ExcelExtended.class_eval do
  def foreach(sheet=nil, &block)
    sheet = @default_sheet unless sheet
    raise ArgumentError, "Error: sheet '#{sheet||'nil'}' not valid" if @default_sheet == nil and sheet==nil
    raise RangeError unless self.sheets.include? sheet

    if @cells_read[sheet]
      raise "sheet #{sheet} already read"
    end

    worksheet = @workbook.worksheet(sheet_no(sheet))
    row_index=1
    worksheet.each(0) do |row|
      row_content = []
      (0..row.size-1).each do |cell_index|
        cell = row.at(cell_index)
        if date_or_time?(row, cell_index)
          vt, v = read_cell_date_or_time(row, cell_index)
        else
          vt, v = read_cell(row, cell_index)
        end
        formula = tr = nil #TODO:???
        col_index = cell_index + 1
        font = row.format(cell_index).font
        font.extend(ExcelExtended::ExcelFontExtensions)
        # set_cell_values(sheet,row_index,col_index,0,v,vt,formula,tr,font)
        row_content << v
      end #row
      yield(row_content, row_index)
      row_index += 1
    end # worksheet
  end
end
