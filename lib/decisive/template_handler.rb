require "csv"
require "action_view"
require "active_support/core_ext/string/inflections"
require "spreadsheet"

module Decisive
  class TemplateHandler
    def self.register
      ActionView::Template.register_template_handler 'decisive', self
    end

    def self.call template, source=template.source
      <<~RUBY
        extend Decisive::DSL
        context = (#{source})

        response.headers["Content-Transfer-Encoding"] = "binary"
        response.headers["Content-Disposition"] = %(attachment; filename="\#{context.filename}")

        if context.csv?
          response.headers["Content-Type"] = "text/csv"

          if controller.is_a?(ActionController::Live)
            begin
              context.each do |row|
                response.stream.write row.to_csv(force_quotes: true)
              end
            ensure
              response.stream.close
            end
            ""
          else
            context.to_csv(force_quotes: true)
          end

        else
          response.headers["Content-Type"] = "application/vnd.ms-excel"
          context.to_xls
        end
      RUBY
    end
  end

  class StreamIncompatibleBlockArgumentError < StandardError
    def message
      "#csv cannot take a block with a record argument while streaming, because the headers have to be known in advance. Either disable streaming by passing `stream: false` to #csv, or convert the template to yield the record to the block passed to each #column call."
    end
  end

  class StreamingNotEnabledByControllerError < StandardError
    def message
      "the controller does not have ActionController::Live included, and thus cannot stream this csv. Either disable streaming by passing `stream: false` to #csv, or include ActionController::Live into the controller."
    end
  end

  module DSL
    def csv records, filename:, stream: true, &block
      if stream
        raise StreamingNotEnabledByControllerError unless controller.is_a?(ActionController::Live)
        raise StreamIncompatibleBlockArgumentError if block.arity != 0
        StreamContext.new([], records, filename, &block)
      else
        RenderContext.new(records, filename, block)
      end
    end

    def xls worksheets=nil, filename:, &block
      if worksheets
        XLSContext.new(worksheets, filename, block)
      else
        XLSWithWorksheetsContext.new(filename, [], &block)
      end
    end
  end

  class XLSWithWorksheetsContext < Struct.new(:filename, :worksheets)
    class Worksheet < Struct.new(:records, :name, :block); end

    def initialize *args, &block
      super
      instance_eval &block
    end

    def to_xls
      to_string(render(Spreadsheet::Workbook.new))
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
        sheet = xls.create_worksheet(name: sanitize_name(worksheet.name))

        rows = to_array(worksheet)

        rows.each.with_index do |row, index|
          sheet.row(index).concat row
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
      xls.write(io)
      io.rewind
      string = io.read
      string.force_encoding(Encoding::ASCII_8BIT)
      string
    end
  end


  class XLSContext < Struct.new(:worksheets, :filename, :block)
    def to_xls
      to_string(render(Spreadsheet::Workbook.new))
    end

    def csv?
      false
    end

    private

    def render xls
      worksheets.each do |name, enumerable|
        sheet = xls.create_worksheet(name: sanitize_name(name))

        rows = to_array(enumerable)

        rows.each.with_index do |row, index|
          sheet.row(index).concat row
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

    def to_array records
      context = RenderContext.new(records, nil, block)
      context.send(:header) + context.send(:body)
    end

    def to_string xls
      io = StringIO.new
      xls.write(io)
      io.rewind
      string = io.read
      string.force_encoding(Encoding::ASCII_8BIT)
      string
    end
  end

  class StreamContext < Struct.new(:columns, :records, :filename)
    class Column < Struct.new(:label, :block); end

    def initialize *args, &block
      super
      instance_eval &block
    end

    def column label, value=nil, &block # field, label: field.to_s.humanize, &block
      value ||= label.parameterize.underscore.to_sym
      block ||= ->(record) { record.send(value) }
      columns << Column.new(label, block)
    end

    def each
      yield header

      records.map do |record|
        row = columns.map do |column|
          column.block.call(record).to_s
        end
        yield row
      end
    end

    def csv?
      true
    end

    private

    def header
      columns.map(&:label)
    end
  end

  class RenderContext < Struct.new(:records, :filename, :block)
    def to_csv(*args, **kwargs)
      (header + body).map do |row|
        row.to_csv(*args, **kwargs)
      end.join
    end

    def csv?
      true
    end

    private

    def header
      [keys]
    end

    def body
      hashes.map do |hash|
        hash.values_at(*keys)
      end
    end

    def keys
      @keys ||= hashes.flat_map(&:keys).uniq
    end

    def hashes
      @hashes ||= records.map do |record|
        Row.new(record, block).to_hash
      end
    end

    class Row < Struct.new(:record, :block)
      module Nothing; end

      def to_hash
        @hash = {}
        instance_exec record, &block
        @hash
      end

      private

      def column key, value=Nothing, &block
        @hash[key] = if block_given?
          block.call(record)
        elsif value.is_a?(Symbol)
          record.send(value)
        elsif value == Nothing
          record.send(key.parameterize.underscore.to_sym)
        else
          value
        end.to_s
      end
    end
  end
end

