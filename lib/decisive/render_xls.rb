require "caxlsx"
require "decisive/renderer"

module Decisive
  class XLSContext < Struct.new(:worksheets, :filename, :block)
    def to_xls
      to_string(render(Axlsx::Package.new))
    end

    def csv?
      false
    end

    private

    def render xls
      worksheets.each do |name, enumerable|
        xls.workbook.add_worksheet(name: sanitize_name(name)) do |sheet|
          Renderer.new(enumerable, block).each do |row|
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

