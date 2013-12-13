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
      # @note Kind is inferred from Class name
      #
      # @return [String] Kind
      def kind
        @kind ||= Activr::Utils.kind_for_class(self, 'timeline')
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

      # Check if given route was already defined
      #
      # @param route_to_check [Timeline::Route] Route to check
      # @return [true, false]
      def have_route?(route_to_check)
        (route_to_check.timeline_class == self) && !self.route_for_kind(route_to_check.kind).blank?
      end

      # Get all routes defined for given activity
      #
      # @param activity [Activity] Activity instance
      # @return [Array<Timeline::Route>] List of Route instances
      def routes_for_activity(activity)
        self.routes.find_all do |defined_route|
          (defined_route.activity_class == activity.class)
        end
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
      #   class UserNewsFeed < Activr::Timeline
      #     recipient User
      #
      #     # ...
      #   end
      #
      # @example Those methods are created:
      #
      #   class User
      #     # fetch latest timeline entries
      #     def user_news(limit, skip = 0)
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
          def #{self.kind}(limit, skip = 0)
            Activr.timeline(#{self.name}, self.id).find(limit, skip)
          end

          # get total number of timeline entries
          def #{self.kind}_count
            Activr.timeline(#{self.name}, self.id).count
          end
        EOS

        self.recipient_class = klass
      end

      # Creates a predefined routing
      #
      # You can either specify a `Proc` (with the `:to` setting) to execute or a `block` to yield everytime
      # an activity is routed to that timeline. That `Proc` or that `block` must return an array of recipients
      # or recipients ids.
      #
      # @param routing_name [Symbol] Routing name
      # @param settings     [Hash]   Settings
      # @option settings [Proc] :to Code to resolve route
      # @yield [Activity] Gives the activity to route to the block
      def routing(routing_name, settings = { }, &block)
        raise "Routing already defined: #{routing_name}" unless self.routings[routing_name].blank?

        if !block && (!settings[:to] || !settings[:to].is_a?(Proc))
          raise "No routing logic provided for #{routing_name}: #{settings.inspect}"
        end

        if block
          raise "It is forbidden to provide a block AND a :to setting" if settings[:to]
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
      :route_for_kind, :have_route?, :routes_for_activity


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

    # Find timeline entries by descending timestamp
    #
    # @param limit [Integer] Max number of entries to find
    # @param skip  [Integer] Number of entries to skip (default: 0)
    # @return [Array<Timeline::Entry>] An array of timeline entries
    def find(limit, skip = 0)
      Activr.storage.find_timeline(self, limit, skip)
    end

    # Get total number of timeline entries
    #
    # @return [Integer]
    def count
      Activr.storage.count_timeline(self.kind, self.recipient_id)
    end

    # Dump humanization of last timeline entries
    #
    # @return [Array<String>] Array of humanized sentences
    def dump(limit = 10)
      self.find(limit).map{ |tl_entry| tl_entry.humanize }
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
