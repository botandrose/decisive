require "action_view"

require "decisive/stream_csv"
require "decisive/render_csv"
require "decisive/xls_with_worksheets"
require "decisive/render_xls"

module Decisive
  class TemplateHandler
    def self.register
      ActionView::Template.register_template_handler 'decisive', self
    end

    def self.call template, source=template.source
      <<~RUBY
        extend Decisive::DSL; context = (#{source})

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
end

