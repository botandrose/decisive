require "caxlsx"
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
      to_string(render(Axlsx::Package.new))
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
        xls.workbook.add_worksheet(name: sanitize_name(worksheet.name)) do |sheet|
          Renderer.new(worksheet.records, worksheet.block).each do |row|
            sheet.add_row row
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
      io = StringIO.new
      io.write xls.to_stream.string
      io.rewind
      string = io.read
      string.force_encoding(Encoding::ASCII_8BIT)
      string
    end
  end
end

