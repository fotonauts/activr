require 'resque'

#
# The defaults hook classes when Resque is detected inside a Rails application
#
module Activr::Async::Resque

  # Class to handle :route_activity hook thanks to a Resque job
  class RouteActivity
    @queue = 'activr_route_activity'

    class << self
      # Enqueue job
      def enqueue(activity)
        ::Resque.enqueue(self, activity.to_hash)
      end

      # Perform job
      def perform(activity_hash)
        # unserialize argument
        activity_hash = Activr::Activity.unserialize_hash(activity_hash)
        activity = Activr::Activity.from_hash(activity_hash)

        # call hook
        Activr::Async.route_activity(activity)
      end
    end # class << self
  end # class RouteActivity

  # Class to handle :timeline_handle hook thanks to a Resque job
  class TimelineHandle
    @queue = 'activr_timeline_handle'

    class << self
      # Enqueue job
      def enqueue(timeline, activity, route)
        ::Resque.enqueue(self, timeline.kind, timeline.recipient_id, activity.to_hash, route.kind)
      end

      # Perform job
      def perform(timeline_kind, recipient_id, activity_hash, route_kind)
        # unserialize arguments
        recipient_id = Activr.storage.unserialize_id_if_necessary(recipient_id)
        activity_hash = Activr::Activity.unserialize_hash(activity_hash)

        timeline_klass = Activr.registry.class_for_timeline(timeline_kind)

        timeline = timeline_klass.new(recipient_id)
        activity = Activr::Activity.from_hash(activity_hash)
        route    = timeline_klass.route_for_kind(route_kind)

        # call hook
        Activr::Async.timeline_handle(timeline, activity, route)
      end
    end # class << self
  end # class TimelineHandle

end # module Activr::Async::Resque
