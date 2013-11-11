module Activr
  # @todo Make it a class-methods-only class ?
  class Dispatcher

    # @todo use activesupport callbacks ?
    #   should_route_activity
    #   will_route_activity
    #   did_route_activity
    attr_reader :callbacks

    # init
    def initialize
      @callbacks = [ ]
    end

    # route an activity
    #
    # @param activity [Activr::Activity] Activity instance to route
    def route(activity)
      raise "Activity must be stored before routing: #{activity.inspect}" if activity._id.nil?

      # iterate on all timelines
      Activr.registry.timelines.values.each do |timeline_class|
        # find routes for that activity
        routes = timeline_class.routes_for_activity(activity)
        routes.each do |route|
          # resolve recipients
          recipients = route.resolve(activity)

          # store activity in timelines
          recipients.each do |recipient|
            if Activr.config.sync
              self.route_to_timeline_recipient(activity, timeline_class, recipient)
            else
              # @todo !!!
              raise "not implemented"
            end
          end
        end
      end
    end

    # route activity to recipient's timeline
    # @todo rename, or move that stuff to Timeline class
    def route_to_timeline_recipient(activity, timeline_class, recipient)
      timeline = timeline_class.new(recipient)
      timeline.store_activity(activity) # @todo Really ?
    end

  end # class Dispatcher
end # module Activr
