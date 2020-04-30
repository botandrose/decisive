require "decisive/version"
require "decisive/template_handler"

module Decisive
  class Rails < ::Rails::Engine
    initializer "decisive.register_template_handler_and_xls_mime_type" do
      TemplateHandler.register
      Mime::Type.register "application/vnd.ms-excel", :xls
    end
  end if defined?(Rails)
end
