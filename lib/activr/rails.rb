module Activr
  class Rails

    class_attribute :controller
    self.controller = nil

    class << self

      def view_context
        @view_context ||= if defined?(::Rails)
          rails_controller = self.controller || begin
            fake_controller = ApplicationController.new
            fake_controller.request = ActionController::TestRequest.new if defined?(ActionController::TestRequest)
            fake_controller
          end

          rails_controller.view_context
        end
      end

      def clear_view_context!
        @view_context = nil
      end

    end # class << self

  end # class Rails
end # module Activr
