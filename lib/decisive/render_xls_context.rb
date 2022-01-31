require "rubyXL"
require "decisive/renderer"

module Decisive
  class RenderXLSContext < Struct.new(:worksheets, :filename, :block)
    class Worksheet < Struct.new(:records, :name, :block); end

    def initialize *args
      super

      self.worksheets ||= []
      if worksheets.none?
        instance_eval &block

      else
        self.worksheets = worksheets.map do |name, records|
          Worksheet.new(records, name, block)
        end
      end
    end

    def to_xls
      workbook = RubyXL::Workbook.new
      workbook.worksheets.pop # rm default worsheet
      to_string(render(workbook))
    end

    def csv?
      false
    end

    private

    def worksheet records, name:, &block
      worksheets.push Worksheet.new(records, name, block)
    end

    def render xls
      worksheets.each do |worksheet|
        sheet = xls.add_worksheet(sanitize_name(worksheet.name)).tap do |sheet|
          Renderer.new(worksheet.records, worksheet.block).each.with_index do |row, row_index|
            row.each.with_index do |cell, cell_index|
              if cell[0] == "="
                sheet.add_cell row_index, cell_index, nil, cell[1..]
              else
                sheet.add_cell row_index, cell_index, cell
              end
            end
          end
        end
      end
      xls
    end

    def sanitize_name name
      name
        .gsub(/[\[\]\*\?:\/\\\t\n\r]/, " ")
        .gsub(/^'/, "")
        .gsub(/'$/, "")
        .strip
        .slice(0,31)
    end

    def to_string xls
      xls.stream.string
    end
  end
end

