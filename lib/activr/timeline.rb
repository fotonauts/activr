module Activr

  #
  # With a timeline you can create complex activity feeds.
  #
  # When creating a {Timeline} class you specify:
  #
  #   - what model in your application owns that timeline: the `recipient`
  #   - what activities will be displayed in that timeline: the `routes`
  #
  # Routes can be resolved thanks to:
  #
  #   - a predefined routing declared with routing method, then specified in the :using route setting
  #   - an activity path specified in the :to route setting
  #   - a call on timeline class method specified in the :using route setting
  #
  # @example For example, this is a user newsfeed timeline
  #
  #   class UserNewsFeedTimeline < Activr::Timeline
  #     # that timeline is for users
  #     recipient User
  #
  #     # this is a predefined routing, to fetch all followers of an activity actor
  #     routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }
  #
  #     # define a routing with a class method, to fetch all followers of an activity album
  #     def self.album_follower(activity)
  #       activity.album.followers
  #     end
  #
  #     # predefined routing: users will see in their news feed when a friend they follow likes a picture
  #     route LikePictureActivity, :using => :actor_follower
  #
  #     # activity path: users will see in their news feed when someone adds a picture in one of their albums
  #     route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"
  #
  #     # method call: users will see in their news feed when someone adds a picture in an album they follow
  #     route AddPictureActivity, :using => :album_follower
  #
  #   end
  #
  # When an activity is routed to a timeline, a Timeline Entry is stored in database and that Timeline Entry contains
  # a copy of the original activity: so Activr uses a "Fanout on write" mecanism to dispatch activities to timelines.
  #
  # Several callbacks are invoked on timeline instance during the activity handling workflow:
  #
  #   - .should_route_activity?       - Returns `false` to skip activity routing
  #   - #should_handle_activity?      - Returns `false` to skip routed activity
  #   - #should_store_timeline_entry? - Returns `false` to cancel timeline entry storing
  #   - #will_store_timeline_entry    - This is your last chance to modify timeline entry before it is stored
  #   - #did_store_timeline_entry     - Called just after timeline entry was stored
  #
  class Timeline

    autoload :Entry, 'activr/timeline/entry'
    autoload :Route, 'activr/timeline/route'


    # Recipient class
    class_attribute :recipient_class, :instance_writer => false
    self.recipient_class = nil

    # Maximum length (0 means 'no limit')
    class_attribute :trim_max_length, :instance_writer => false
    self.trim_max_length = 0

    # Predefined routings
    class_attribute :routings, :instance_writer => false
    self.routings = { }

    # Routes (ordered by priority)
    class_attribute :routes, :instance_writer => false
    self.routes = [ ]


    class << self

      # Get timeline class kind
      #
      # @example
      #   UserNewsFeedTimeline.kind
      #   # => 'user_news_feed'
      #
      # @note Kind is inferred from Class name, unless `#set_kind` method is used to force a custom value
      #
      # @return [String] Kind
      def kind
        @kind ||= @forced_kind || Activr::Utils.kind_for_class(self, 'timeline')
      end

      # Set timeline kind
      #
      # @note Default kind is inferred from class name
      #
      # @param forced_kind [String] Timeline kind
      def set_kind(forced_kind)
        @forced_kind = forced_kind.to_s
      end

      # Get route defined with given kind
      #
      # @param route_kind [String] Route kind
      # @return [Timeline::Route] Corresponding Route instance
      def route_for_kind(route_kind)
        self.routes.find do |defined_route|
          (defined_route.kind == route_kind)
        end
      end

      # Get route defined with given kind
      #
      # @param routing_kind   [String] Routing kind
      # @param activity_class [Class]  Activity class
      # @return [Timeline::Route] Corresponding Route instance
      def route_for_routing_and_activity(routing_kind, activity_class)
        self.route_for_kind(Activr::Timeline::Route.kind_for_routing_and_activity(routing_kind, activity_class.kind))
      end

      # Get all routes defined for given activity
      #
      # @param activity [Activity] Activity instance
      # @return [Array<Timeline::Route>] List of Route instances
      def routes_for_activity(activity_class)
        self.routes.find_all do |defined_route|
          (defined_route.activity_class == activity_class)
        end
      end

      # Check if given route was already defined
      #
      # @param route_to_check [Timeline::Route] Route to check
      # @return [true, false]
      def have_route?(route_to_check)
        (route_to_check.timeline_class == self) && !self.route_for_kind(route_to_check.kind).blank?
      end

      # Callback: just before trying to route given activity
      #
      # @note MAY be overriden by child class
      #
      # @param activity [Activity] Activity to route
      # @return [true,false] `false` to skip activity
      def should_route_activity?(activity)
        true
      end

      # Is it a valid recipient
      #
      # @param recipient [Object] Recipient to check
      # @return [true, false]
      def valid_recipient?(recipient)
        (self.recipient_class && recipient.is_a?(self.recipient_class)) || Activr.storage.valid_id?(recipient)
      end

      # Get recipient id for given recipient
      #
      # @param recipient [Object] Recipient
      # @return [Object] Recipient id
      def recipient_id(recipient)
        if self.recipient_class && recipient.is_a?(self.recipient_class)
          recipient.id
        elsif Activr.storage.valid_id?(recipient)
          recipient
        else
          raise "Invalid recipient #{recipient.inspect} for timeline #{self}"
        end
      end


      #
      # Class interface
      #

      # Set recipient class
      #
      # @example Several instance methods are injected in given `klass`, for example with timeline:
      #
      #   class UserNewsFeedTimeline < Activr::Timeline
      #     recipient User
      #
      #     # ...
      #   end
      #
      # @example Those methods are created:
      #
      #   class User
      #     # fetch latest timeline entries
      #     def user_news(limit, options = { })
      #       # ...
      #     end
      #
      #     # get total number of timeline entries
      #     def user_news_count
      #       # ...
      #     end
      #   end
      #
      # @param klass [Class] Recipient class
      def recipient(klass)
        raise "Routing class already defined: #{self.recipient_class}" unless self.recipient_class.blank?

        # inject sugar methods
        klass.class_eval <<-EOS, __FILE__, __LINE__
          # fetch latest timeline entries
          def #{self.kind}(limit, options = { })
            Activr.timeline(#{self.name}, self.id).find(limit, options)
          end

          # get total number of timeline entries
          def #{self.kind}_count
            Activr.timeline(#{self.name}, self.id).count
          end
        EOS

        self.recipient_class = klass
      end

      # Set maximum length
      #
      # @param value [Integer] Maximum timeline length
      def max_length(value)
        self.trim_max_length = value
      end

      # Creates a predefined routing
      #
      # You can either specify a `Proc` (with the `:to` setting) to execute or a `block` to yield everytime
      # an activity is routed to that timeline. That `Proc` or that `block` must return an array of recipients
      # or recipients ids.
      #
      # @param routing_name [Symbol,String] Routing name
      # @param settings     [Hash]   Settings
      # @option settings [Proc] :to Code to resolve route
      # @yield [Activity] Gives the activity to route to the block
      def routing(routing_name, settings = { }, &block)
        routing_name = routing_name.to_s
        raise "Routing already defined: #{routing_name}" unless self.routings[routing_name].blank?

        if !block && (!settings[:to] || !settings[:to].is_a?(Proc))
          raise "No routing logic provided for #{routing_name}: #{settings.inspect}"
        end

        if block
          raise "It is forbidden to provide a block AND a :to setting" if settings[:to]
          settings = settings.merge(:to => block)
        end

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.routings = self.routings.merge(routing_name => settings)

        # create method
        class_eval <<-EOS, __FILE__, __LINE__
          # eg: actor_follower(activity)
          def self.#{routing_name}(activity)
            self.routings['#{routing_name}'][:to].call(activity)
          end
        EOS
      end

      # Define a route for an activity
      #
      # @param activity_class [Class] Activity to route
      # @param settings (see Timeline::Route#initialize)
      # @option settings (see Timeline::Route#initialize)
      def route(activity_class, settings = { })
        new_route = Activr::Timeline::Route.new(self, activity_class, settings)
        raise "Route already defined: #{new_route.inspect}" if self.have_route?(new_route)

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.routes += [ new_route ]
      end

    end # class << self


    extend Forwardable

    # Forward methods to class
    def_delegators "self.class",
      :kind,
      :route_for_kind, :route_for_routing_and_activity, :routes_for_activity, :have_route?


    # @param rcpt Recipient instance, or recipient id
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

    # Get recipient instance
    #
    # @return [Object] Recipient instance
    def recipient
      @recipient ||= self.recipient_class.find(@recipient_id)
    end

    # Get recipient id
    #
    # @return [Object] Recipient id
    def recipient_id
      @recipient_id ||= @recipient.id
    end

    # Handle activity
    #
    # @param activity [Activity] Activity to handle
    # @param route [Timeline::Route] The route that caused that activity handling
    # @return [Timeline::Entry] Created timeline entry
    def handle_activity(activity, route)
      # create timeline entry
      klass = Activr.registry.class_for_timeline_entry(self.kind, route.kind)
      timeline_entry = klass.new(self, route.routing_kind, activity)

      # store with callbacks
      if self.should_store_timeline_entry?(timeline_entry)
        self.will_store_timeline_entry(timeline_entry)

        # store
        timeline_entry.store!

        self.did_store_timeline_entry(timeline_entry)

        # trim timeline
        self.trim!
      end

      timeline_entry._id.blank? ? nil : timeline_entry
    end

    # Find timeline entries by descending timestamp
    #
    # @param limit (see Storage#find_timeline)
    # @param options (see Storage#find_timeline)
    # @option options (see Storage#find_timeline)
    # @return (see Storage#find_timeline)
    def find(limit, options = { })
      Activr.storage.find_timeline(self, limit, options)
    end

    # Get total number of timeline entries
    #
    # @param options (see Storage#count_timeline)
    # @option options (see Storage#count_timeline)
    # @return (see Storage#count_timeline)
    def count(options = { })
      Activr.storage.count_timeline(self, options)
    end

    # Dump humanization of last timeline entries
    #
    # @param options [Hash] Options hash
    # @option options (see Activr::Timeline::Entry#humanize)
    # @option options [Integer] :nb Number of timeline entries to dump (default: 100)
    # @return [Array<String>] Array of humanized sentences
    def dump(options = { })
      options = options.dup

      limit = options.delete(:nb) || 100

      self.find(limit).map{ |tl_entry| tl_entry.humanize(options) }
    end

    # Delete timeline entries
    #
    # @param options (see Storage#delete_timeline)
    # @option options (see Storage#delete_timeline)
    def delete(options = { })
      Activr.storage.delete_timeline(self, options)
    end

    # Remove old timeline entries
    def trim!
      # check if trimming is needed
      if (self.trim_max_length > 0) && (self.count > self.trim_max_length)
        last_tle = self.find(1, :skip => self.trim_max_length - 1).first
        if last_tle
          self.delete(:before => last_tle.activity.at)
        end
      end
    end


    #
    # Callbacks
    #

    # Callback: just before trying to handle routed activity
    #
    # @note MAY be overriden by child class
    #
    # @param activity [Activity] Activity to handle
    # @param route [Timeline::Route] Route that caused that handling
    # @return [true,false] Returns `false` to skip activity
    def should_handle_activity?(activity, route)
      true
    end

    # Callback: check if given timeline entry should be stored
    #
    # @note MAY be overriden by child class
    #
    # @param timeline_entry [Timeline::Entry] Timeline entry that should be stored
    # @return [true,false] Returns `false` to cancel storing
    def should_store_timeline_entry?(timeline_entry)
      true
    end

    # Callback: just before storing timeline entry into timeline
    #
    # @note MAY be overriden by child class
    #
    # @param timeline_entry [Timeline::Entry] Timeline entry that will be stored
    def will_store_timeline_entry(timeline_entry)
      # NOOP
    end

    # Callback: just after timeline entry was stored
    #
    # @note MAY be overriden by child class
    #
    # @param timeline_entry [Timeline::Entry] Timeline entry that has been stored
    def did_store_timeline_entry(timeline_entry)
      # NOOP
    end

  end # class Timeline

end # module Activr
