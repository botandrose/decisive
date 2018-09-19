require "csv"
require "action_view"
require "active_support/core_ext/string/inflections"

module Decisive
  class TemplateHandler
    def self.register
      ActionView::Template.register_template_handler 'decisive', self
    end

    def self.call template
      <<~RUBY
        extend Decisive::DSL
        context = (#{template.source})
        response.headers["Content-Disposition"] = %(attachment; filename="\#{context.filename}")
        context.to_csv
      RUBY
    end
  end

  module DSL
    def csv records, filename:, &block
      Context.new([], records, filename).tap do |context|
        context.instance_eval &block
      end
    end
  end

  class Context < Struct.new(:columns, :records, :filename)
    class Column < Struct.new(:field, :label, :block); end

    def column field, label: field.to_s.humanize, &block
      block ||= ->(record) { record.send(field) }
      columns << Column.new(field, label, block)
    end

    def to_csv
      rows
        .map { |rows| rows.map(&:to_s) }
        .map(&:to_csv)
        .join
    end

    private

    def rows
      [header] + body
    end

    def header
      columns.map(&:label)
    end

    def body
      records.map do |record|
        columns.map do |column|
          column.block.call(record)
        end
      end
    end
  end
end

