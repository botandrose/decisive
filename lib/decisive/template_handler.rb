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
        #{template.source}
        response.headers["Content-Disposition"] = %(attachment; filename="\#{@filename}")
        rows
          .map { |rows| rows.map(&:to_s) }
          .map(&:to_csv)
          .join
      RUBY
    end
  end

  module DSL
    def self.extended object
      object.instance_variable_set :@columns, []
    end

    class Column < Struct.new(:field, :label, :block); end

    def column field, label: field.to_s.humanize, &block
      block ||= ->(record) { record.send(field) }
      @columns << Column.new(field, label, block)
    end

    def header
      @columns.map(&:label)
    end

    def body
      @records.map do |record|
        @columns.map do |column|
          column.block.call(record)
        end
      end
    end

    def rows
      [header] + body
    end
  end
end

