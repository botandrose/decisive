require "decisive/version"
require "decisive/template_handler"

module Decisive
  class Rails < ::Rails::Engine
    initializer "decisive.register_template_handler" do
      TemplateHandler.register
    end
  end if defined?(Rails)
end
