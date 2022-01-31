require "csv"
require "active_support/core_ext/string/inflections"

module Decisive
  class StreamCSVContext < Struct.new(:records, :filename, :block)
    class Column < Struct.new(:label, :block); end

    def initialize *args
      super
      @columns = []
      instance_eval &block
    end

    attr_reader :columns

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

