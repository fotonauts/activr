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
          # check if timeline refuses that activity
          next unless timeline_class.should_route_activity?(activity)

          # store activity in timelines
          self.recipients_for_timeline(timeline_class, activity).each do |recipient, route|
            if Activr.config.async
              # @todo !!!
              raise "not implemented"
            else
              timeline = timeline_class.new(recipient)
              timeline.handle_activity(activity, route)
            end
          end
        end
      end
    end

    def recipients_for_timeline(timeline_class, activity)
      result = { }

      routes = timeline_class.routes_for_activity(activity)
      routes.each do |route|
        route.resolve(activity).each do |recipient|
          recipient_id = timeline_class.recipient_id(recipient)

          # keep only one route per recipient
          if result[recipient_id].nil?
            result[recipient_id] = { :rcpt => recipient, :route => route }
          end
        end
      end

      result.inject({ }) do |memo, (recipient_id, infos)|
        memo[infos[:rcpt]] = infos[:route]
        memo
      end
    end

  end # class Dispatcher
end # module Activr
