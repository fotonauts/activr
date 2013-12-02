module Activr
  module Async

    autoload :Resque, 'activr/async/resque'

    class << self
      # run hook
      def hook(name, *args)
        if Activr.config.async[name]
          # async
          Activr.config.async[name].enqueue(*args)
        else
          # sync
          self.__send__(name, *args)
        end
      end


      #
      # Hooks
      #

      # route an activity
      def route_activity(activity)
        Activr.dispatcher.route(activity)
      end

      # timeline handles an activity thanks to given route
      def timeline_handle(timeline, activity, route)
        timeline.handle_activity(activity, route)
      end
    end # class << self

  end # module Async
end # module Activr
