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
        response.headers["Content-Type"] = "text/csv"
        response.headers["Content-Transfer-Encoding"] = "binary"
        response.headers["Content-Disposition"] = %(attachment; filename="\#{context.filename}")

        if controller.respond_to?(:new_controller_thread) # has AC::Live mixed in
          begin
            context.each do |row|
              response.stream.write row.to_csv
            end
          ensure
            response.stream.close
          end
        else
          context.to_csv
        end
      RUBY
    end
  end

  module DSL
    def csv records, filename:, &block
      Context.new(records, filename, block)
    end
  end

  class Context < Struct.new(:records, :filename, :block)
    def each &block
      block.call header
      body.each &block.method(:call)
    end

    def to_csv
      (header + body).map(&:to_csv).join
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
  end

  class Row < Struct.new(:record, :block)
    def to_hash
      @hash = {}
      instance_exec record, &block
      @hash
    end

    private

    def column key, value=nil, &block
      @hash[key] = if block_given?
        block.call(record)
      elsif value.is_a?(Symbol)
        record.send(value)
      elsif value.nil?
        record.send(key.parameterize.underscore.to_sym)
      else
        value
      end.to_s
    end
  end
end

