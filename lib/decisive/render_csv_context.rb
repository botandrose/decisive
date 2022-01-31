require "csv"
require "active_support/core_ext/string/inflections"
require "decisive/renderer"

module Decisive
  class RenderCSVContext < Struct.new(:records, :filename, :block)
    def to_csv(*args, **kwargs)
      Renderer.new(records, block).map do |row|
        row.to_csv(*args, **kwargs)
      end.join
    end

    def csv?
      true
    end
  end
end

