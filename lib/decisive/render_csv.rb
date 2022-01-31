require "csv"
require "active_support/core_ext/string/inflections"

module Decisive
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

