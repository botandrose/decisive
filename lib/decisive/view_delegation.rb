module Decisive
  # Blocks in a decisive template are evaluated against decisive's own objects,
  # so without this they would be cut off from the view's helper methods.
  module ViewDelegation
    private

    def method_missing name, *args, **kwargs, &block
      return super unless view.respond_to?(name, true)
      view.send(name, *args, **kwargs, &block)
    rescue NameError => error
      # Keep the template's own line at the top of the backtrace.
      error.set_backtrace(error.backtrace.reject { |line| line.include?(__FILE__) })
      raise
    end

    def respond_to_missing? name, include_private = false
      view.respond_to?(name, include_private) || super
    end
  end
end
