module Activr
  class Timeline

    autoload :Entry, 'activr/timeline/entry'
    autoload :Route, 'activr/timeline/route'

    # recipient class
    class_attribute :recipient_class, :instance_writer => false

    # routings
    class_attribute :routings, :instance_writer => false
    self.routings = { }

    # routes (ordered by priority)
    class_attribute :routes, :instance_writer => false
    self.routes = [ ]


    class << self

      # timeline kind
      def kind
        @kind ||= Activr::Utils.kind_for_class(self, 'timeline')
      end

      # get route defined with given kind
      def route_for_kind(route_kind)
        self.routes.find do |defined_route|
          (defined_route.kind == route_kind)
        end
      end

      # check if given route was already defined
      def have_route?(route_to_check)
        (route_to_check.timeline_class == self) && !self.route_for_kind(route_to_check.kind).blank?
      end

      # get all routes defined for given activity
      def routes_for_activity(activity)
        self.routes.find_all do |defined_route|
          (defined_route.activity_class == activity.class)
        end
      end


      #
      # Class interface
      #

      # define a routing
      def routing(routing_name, settings = { }, &block)
        raise "Routing already defined: #{routing_name}" unless self.routings[routing_name].blank?

        if !block && (!settings[:to] || !settings[:to].is_a?(Proc))
          raise "No routing logic provided for #{routing_name}: #{settings.inspect}"
        end

        if block
          raise "Forbidden to provide a block AND a :to setting" if settings[:to]
          settings = settings.merge(:to => block)
        end

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.routings = self.routings.merge(routing_name.to_sym => settings)

        # create method
        class_eval <<-EOS, __FILE__, __LINE__
          # eg: actor_follower(activity)
          def self.#{routing_name}(activity)
            self.routings[:#{routing_name}][:to].call(activity)
          end
        EOS
      end

      # define a route for an activity
      def route(activity_class, settings = { })
        new_route = Activr::Timeline::Route.new(self, activity_class, settings)
        raise "Route already defined: #{new_route.inspect}" if self.have_route?(new_route)

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.routes += [ new_route ]
      end

    end # class << self


    # init
    #
    # @param rcpt Recipient instance or recipient id
    def initialize(rcpt)
      if rcpt.is_a?(self.recipient_class)
        @recipient    = rcpt
        @recipient_id = rcpt._id
      else
        @recipient    = nil
        @recipient_id = rcpt
      end

      if (@recipient.blank? && @recipient_id.blank?)
        raise "No recipient provided"
      end
    end

    # get recipient instance
    def recipient
      @recipient ||= self.recipient_class.find(@recipient_id)
    end

    # get recipient id
    def recipient_id
      @recipient_id ||= @recipient._id
    end

    # activity kind
    def kind
      self.class.kind
    end

    # store activity
    #
    # @param activity [Activr::Activity] Activity to store
    # @param route [Activr::Timeline::Route] The route that caused that activity storing
    # @return [Activr::Timeline::Entry] The created timeline entry
    def store_activity(activity, route)
      # create timeline entry
      timeline_entry = Activr::Timeline::Entry.new({
        :timeline     => self,
        :activity     => activity,
        :routing_kind => route.routing_kind,
      })

      # store
      timeline_entry.store!

      timeline_entry
    end

  end # class Timeline
end # module Activr
