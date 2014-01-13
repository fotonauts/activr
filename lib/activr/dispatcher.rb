module Activr

  #
  # The dispatcher is the component that is in charge of routing activities to timelines.
  #
  # The dispatcher singleton is accessible with {Activr.dispatcher}
  #
  class Dispatcher

    # Route an activity
    #
    # @param activity [Activity] Activity to route
    # @return [Integer] The number of resolved recipients that will handle activity
    def route(activity)
      raise "Activity must be stored before routing: #{activity.inspect}" if activity._id.nil?

      result = 0

      activity.run_callbacks(:route) do
        # iterate on all timelines
        Activr.registry.timelines.values.each do |timeline_class|
          # check if timeline refuses that activity
          next unless timeline_class.should_route_activity?(activity)

          # store activity in timelines
          self.recipients_for_timeline(timeline_class, activity).each do |recipient, route|
            result += 1

            timeline = timeline_class.new(recipient)
            if timeline.should_handle_activity?(activity, route)
              Activr::Async.hook(:timeline_handle, timeline, activity, route)
            end
          end
        end
      end

      result
    end

    # Find recipients for given activity in given timeline
    #
    # @api private
    #
    # @param timeline_class [Class]    Timeline class
    # @param activity       [Activity] Activity instance
    # @return [Hash{Object=>Timeline::Route}] Recipients with corresponding Routes
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
