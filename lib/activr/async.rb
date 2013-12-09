module Activr

  #
  # Async hooks module
  #
  # The async hooks module permits to plug any job system to run some part if Activr's code asynchronously.
  #
  # Possible hooks are:
  #   - :route_activity - An activity must me routed by the Dispatcher
  #   - :timeline_handle - An activity must be handled by a timeline
  #
  # A hook class:
  #   - must implement a `#enqueue` method, used to enqueue the async job
  #   - must call `Activr::Async.<hook_name>` method in the async job
  #
  # Hook classes to use are specified thanks to the `config.async` hash.
  #
  # When Resque is detected inside a Rails application then defaults hooks are provided out of the box (@see {Activr::Async::Resque} module).
  #
  # @example The default :route_activity hook handler when Resque is detected in a Rails application:
  #
  #   # config
  #   Activr.configure do |config|
  #     config.async[:route_activity] ||= Activr::Async::Resque::RouteActivity
  #   end
  #
  #   class Activr::Async::Resque::RouteActivity
  #     @queue = 'activr_route_activity'
  #
  #     class << self
  #       def enqueue(activity)
  #         ::Resque.enqueue(self, activity.to_hash)
  #       end
  #
  #       def perform(activity_hash)
  #         # unserialize argument
  #         activity_hash = Activr::Activity.unserialize_hash(activity_hash)
  #         activity = Activr::Activity.from_hash(activity_hash)
  #
  #         # call hook
  #         Activr::Async.route_activity(activity)
  #       end
  #     end # class << self
  #   end # class RouteActivity
  #
  module Async

    autoload :Resque, 'activr/async/resque'

    class << self
      # Run hook
      #
      # If an async class is defined for that hook name then it is used to process
      # the hook asynchronously, else the hooked code is run immediately.
      #
      # @param name [Symbol] Hook name to run
      # @param args [Array]  Hook parameters
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

      # Hook: route an activity
      #
      # @param activity [Activr::Activity] Activity to route
      def route_activity(activity)
        Activr.dispatcher.route(activity)
      end

      # Hook: timeline handles an activity thanks to given route
      #
      # @param timeline [Activr::Timeline]        Timeline that handles the activity
      # @param activity [Activr:Activity]         Activity to handle
      # @param route    [Activr::Timeline::Route] The route causing that activity handling
      def timeline_handle(timeline, activity, route)
        timeline.handle_activity(activity, route)
      end
    end # class << self

  end # module Async

end # module Activr
