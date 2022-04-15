module Decisive
  class Renderer < Struct.new(:records, :block)
    include Enumerable

    def each &block
      (header + body).each(&block)
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
      @hashes ||= begin
        method = records.respond_to?(:find_each) ? :find_each : :each
        records.send(method).map do |record|
          Row.new(record, block).to_hash
        end
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

