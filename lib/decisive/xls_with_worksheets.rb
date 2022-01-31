require "caxlsx"

module Decisive
  class XLSWithWorksheetsContext < Struct.new(:filename, :worksheets)
    class Worksheet < Struct.new(:records, :name, :block); end

    def initialize *args, &block
      super
      instance_eval &block
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
          rows = to_array(worksheet)
          rows.each do |row|
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

    def to_array worksheet
      context = RenderContext.new(worksheet.records, nil, worksheet.block)
      context.send(:header) + context.send(:body)
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

