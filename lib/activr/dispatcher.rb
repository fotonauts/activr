module Activr
  class Dispatcher

    class << self

      # @todo !!!

    end # class << self

    # init
    def initialize
      # @todo !!!
    end

    # route an activity
    #
    # @param activity [Activr::Activity] Activity instance to route
    def route(activity)
      raise "Activity must be stored before routing: #{activity.inspect}" if activity._id.nil?

      # route to all timelines
      Activr.registry.timelines.values.each do |timeline_class|
        # find routes for that activity
        routes = timeline_class.routes_for_activity(activity)
        routes.each do |route|
          # resolve route recipients
          recipients = route.resolve(activity)

          # @todo !!!
          raise "not implemented"
        end
      end
    end

  end # class Dispatcher
end # module Activr
