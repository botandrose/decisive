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
          ""
        else
          context.to_csv
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
        raise StreamingNotEnabledByControllerError unless controller.respond_to?(:new_controller_thread) # has AC::Live mixed in
        raise StreamIncompatibleBlockArgumentError if block.arity != 0
        StreamContext.new([], records, filename, &block)
      else
        RenderContext.new(records, filename, block)
      end
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

    private

    def header
      columns.map(&:label)
    end
  end

  class RenderContext < Struct.new(:records, :filename, :block)
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
end

