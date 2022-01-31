require "csv"
require "active_support/core_ext/string/inflections"

module Decisive
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
end

