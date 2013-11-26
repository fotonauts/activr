module Activr

  class Storage

    autoload :MongoDriver, 'activr/storage/mongo_driver'

    attr_reader :driver

    # init
    def initialize
      @driver = Activr::Storage::MongoDriver.new
    end

    # Insert a new activity
    #
    # @param activity [Activr::Activity] Activity to insert
    # @return The `_id` of the document in collection
    def insert_activity(activity)
      # serialize
      activity_hash = activity.to_hash

      # run hook
      Activr.registry.run_hook(:will_insert_activity, activity_hash)

      # insert
      self.driver.insert_activity(activity_hash)
    end

    # Fetch an activity
    #
    # @param activity_id [String|BSON::ObjectId] Activity id
    # @return [Activr::Activity] An activity instance
    def fetch_activity(activity_id)
      activity_id = ::BSON::ObjectId.from_string(activity_id) if activity_id.is_a?(String)

      # fetch
      activity_hash = self.driver.find_activity(activity_id)
      if activity_hash
        # run hook
        Activr.registry.run_hook(:did_fetch_activity, activity_hash)

        # unserialize
        Activr::Activity.from_hash(activity_hash)
      else
        nil
      end
    end

    # Fetch last activities
    #
    # Please note that if you use others selectors then 'limit' argument and 'skip' option
    # then you have to setup corresponding indexes in database.
    #
    # @todo Add doc explaining howto setup indexes
    #
    # @param limit [Integer] Max number of activities to fetch
    # @param options [Hash] Options hash:
    #   :skip     => [Integer] Number of activities to skip (default: 0)
    #   :before   => [Time] Fetch activities generated before that datetime (excluding)
    #   :after    => [Time] Fetch activities generated after that datetime (excluding)
    #   :entities => [Hash of Sym => String] Filter by entities values (empty means 'all values')
    #   :only     => [Array of Class] Fetch only those activities
    #   :except   => [Array of Class] Skip those activities
    # @return [Array] An array of Activr::Activity instances
    def fetch_activities(limit, options = { })
      # default options
      options = {
        :skip     => 0,
        :before   => nil,
        :after    => nil,
        :entities => { },
        :only     => [ ],
        :except   => [ ],
      }.merge(options)

      # find
      result = self.driver.find_activities(limit, options).map do |activity_hash|
        # run hook
        Activr.registry.run_hook(:did_fetch_activity, activity_hash)

        # unserialize
        Activr::Activity.from_hash(activity_hash)
      end

      result
    end

    # Insert a new timeline entry
    #
    # @param timeline_entry [Activr::Timeline::Entry] Timeline entry to insert
    # @return The `_id` of the document in collection
    def insert_timeline_entry(timeline_entry)
      # serialize
      timeline_entry_hash = timeline_entry.to_hash

      # run hook
      Activr.registry.run_hook(:will_insert_timeline_entry, timeline_entry_hash)

      # insert
      self.driver.insert_timeline_entry(timeline_entry.timeline.kind, timeline_entry_hash)
    end

    # Fetch a timeline entry
    #
    # @param timeline_kind [String] Timeline kind
    # @param tl_entry_id   [String|BSON::ObjectId] Timeline entry id
    # @return [Array] An array of Activr::Timeline::Entry instances
    def fetch_timeline_entry(timeline_kind, tl_entry_id)
      tl_entry_id = ::BSON::ObjectId.from_string(tl_entry_id) if tl_entry_id.is_a?(String)

      # fetch
      timeline_entry_hash = self.driver.find_timeline_entry(timeline_kind, tl_entry_id)
      if timeline_entry_hash
        # run hook
        Activr.registry.run_hook(:did_fetch_timeline_entry, timeline_entry_hash)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash)
      else
        nil
      end
    end

    # Fetch timeline entries by descending timestamp
    #
    # @param timeline_kind [String] Timeline kind
    # @param recipient_id  [String] Recipient id
    # @param limit         [Integer] Max number of entries to fetch
    # @param skip          [Integer] Number of entries to skip (default: 0)
    # @return [Array] An array of Activr::Timeline::Entry instances
    def fetch_timeline(timeline_kind, recipient_id, limit, skip = 0)
      # find
      result = self.driver.find_timeline_entries(timeline_kind, recipient_id, limit, skip).map do |timeline_entry_hash|
        # run hook
        Activr.registry.run_hook(:did_fetch_timeline_entry, timeline_entry_hash)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash)
      end

      result
    end

  end # class Storage

end # module Activr
