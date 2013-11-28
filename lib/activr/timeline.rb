module Activr
  class Timeline

    autoload :Entry, 'activr/timeline/entry'
    autoload :Route, 'activr/timeline/route'


    # recipient class
    class_attribute :recipient_class, :instance_writer => false
    self.recipient_class = nil

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

      # callback just before trying to route given activity
      #
      # @param activity [Activr::Activity] Activity to route
      # @return [Boolean] `false` to skip activity
      def should_route_activity?(activity)
        # MAY be overriden by child class
        true
      end

      # is it a valid recipient ?
      def valid_recipient?(recipient)
        (self.recipient_class && recipient.is_a?(self.recipient_class)) || recipient.is_a?(String) || (defined?(::BSON) && recipient.is_a?(::BSON::ObjectId))
      end

      # get recipient id for given recipient
      def recipient_id(recipient)
        if self.recipient_class && recipient.is_a?(self.recipient_class)
          recipient.id
        elsif recipient.is_a?(String) || (defined?(::BSON) && recipient.is_a?(::BSON::ObjectId))
          recipient
        else
          raise "Invalid recipient #{recipient.inspect} for timeline #{self}"
        end
      end

      # helper
      def _inject_methods_to_recipient_class(klass)
        puts "self.kind: #{self.kind}"

        # inject methods to recipient class
        klass.class_eval <<-EOS, __FILE__, __LINE__
          # fetch last timeline entries
          def #{self.kind}(limit, skip = 0)
            Activr.timeline(#{self.name}, self.id).fetch(limit, skip)
          end

          # get total number of news feed entries
          def #{self.kind}_count
            Activr.timeline(#{self.name}, self.id).count
          end
        EOS
      end


      #
      # Class interface
      #

      # set recipient class
      def recipient(klass)
        raise "Routing class already defined: #{self.recipient_class}" unless self.recipient_class.blank?

        # inject sugar methods
        self._inject_methods_to_recipient_class(klass)

        self.recipient_class = klass
      end

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


    extend Forwardable

    # forward methods to class
    def_delegators "self.class",
      :kind,
      :route_for_kind, :have_route?, :routes_for_activity


    # init
    #
    # @param rcpt Recipient instance or recipient id
    def initialize(rcpt)
      if self.recipient_class.nil?
        raise "Missing recipient_class attribute for timeline: #{self}"
      end

      if rcpt.is_a?(self.recipient_class)
        @recipient    = rcpt
        @recipient_id = rcpt.id
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
      @recipient_id ||= @recipient.id
    end

    # handle activity
    #
    # @param activity [Activr::Activity] Activity to handle
    # @param route [Activr::Timeline::Route] The route that caused that activity handling
    # @return [Activr::Timeline::Entry] The created timeline entry
    def handle_activity(activity, route)
      # create timeline entry
      timeline_entry = Activr::Timeline::Entry.new(self, route.routing_kind, activity)

      # store with callbacks
      if self.should_store_timeline_entry?(timeline_entry)
        self.will_store_timeline_entry(timeline_entry)

        # store
        timeline_entry.store!

        self.did_store_timeline_entry(timeline_entry)
      end

      timeline_entry._id.blank? ? nil :timeline_entry
    end

    # Fetch timeline entries by descending timestamp
    #
    # @param limit [Integer] Max number of entries to fetch
    # @param skip  [Integer] Number of entries to skip (default: 0)
    # @return [Array] An array of Activr::Timeline::Entry instances
    def fetch(limit, skip = 0)
      Activr.storage.fetch_timeline(self.kind, self.recipient_id, limit, skip)
    end

    # Get total number of timeline entries
    def count
      Activr.storage.count_timeline(self.kind, self.recipient_id)
    end

    # Dump humanization of last timeline entries
    def dump(limit = 10)
      self.fetch(limit).map{ |tl_entry| tl_entry.humanize }
    end


    #
    # Callbacks
    #

    # callback just before trying to handle given activity
    #
    # @param activity [Activr::Activity] Activity to handle
    # @param activity [Activr::Timeline::Route] Route that caused that handling
    # @return [Boolean] `false` to skip activity
    def should_handle_activity?(activity, route)
      # MAY be overriden by child class
      true
    end

    # callback to check if given timeline entry should be stored
    #
    # @param activity [Activr::Timeline::Entry] The timeline entry that should be stored
    # @return [Boolean] `false` to cancel storing
    def should_store_timeline_entry?(timeline_entry)
      # MAY be overriden by child class
      true
    end

    # callback just before storing timeline entry in database
    #
    # @param activity [Activr::Timeline::Entry] The timeline entry that will be stored
    def will_store_timeline_entry(timeline_entry)
      # MAY be overriden by child class
    end

    # callback just after storing timeline entry in database
    #
    # @param activity [Activr::Timeline::Entry] The timeline entry that have been stored
    def did_store_timeline_entry(timeline_entry)
      # MAY be overriden by child class
    end

  end # class Timeline
end # module Activr
