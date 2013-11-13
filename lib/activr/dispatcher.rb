module Activr
  class Dispatcher

    # route an activity
    #
    # @param activity [Activr::Activity] Activity to route
    def route(activity)
      raise "Activity must be stored before routing: #{activity.inspect}" if activity._id.nil?

      activity.run_callbacks(:route) do
        # iterate on all timelines
        Activr.registry.timelines.values.each do |timeline_class|
          # find routes for that activity
          routes = timeline_class.routes_for_activity(activity)
          routes.each do |route|
            # resolve recipients
            recipients = route.resolve(activity)

            # @todo Store in only one timeline
            # @todo Timelines ordered by priority

            # store activity in timelines
            recipients.each do |recipient|
              if Activr.config.sync
                timeline = timeline_class.new(recipient)
                timeline.store_activity(activity, route)
              else
                # @todo !!!
                raise "not implemented"
              end
            end
          end
        end
      end
    end

  end # class Dispatcher
end # module Activr
