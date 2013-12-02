module Activr

  class Storage

    autoload :MongoDriver, 'activr/storage/mongo_driver'

    attr_reader :driver

    # init
    def initialize
      @driver = Activr::Storage::MongoDriver.new

      @hooks = { }
    end

    # check if this is a serialized document id
    def serialized_id?(doc_id)
      self.driver.serialized_id?(doc_id)
    end

    # return an unserialized document id
    def unserialize_id(doc_id)
      self.driver.unserialize_id(doc_id)
    end

    # helper
    def unserialize_id_if_necessary(doc_id)
      self.serialized_id?(doc_id) ? self.unserialize_id(doc_id) : doc_id
    end

    # Insert a new activity
    #
    # @param activity [Activr::Activity] Activity to insert
    # @return The `_id` of the document in collection
    def insert_activity(activity)
      # serialize
      activity_hash = activity.to_hash

      # run hook
      self.run_hook(:will_insert_activity, activity_hash)

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
        self.run_hook(:did_fetch_activity, activity_hash)

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
        self.run_hook(:did_fetch_activity, activity_hash)

        # unserialize
        Activr::Activity.from_hash(activity_hash)
      end

      result
    end

    # Count number of activities
    #
    # Please note that if you use one of options selector then you have to setup
    # corresponding indexes in database.
    #
    # @todo Add doc explaining howto setup indexes
    #
    # @param options [Hash] Options hash:
    #   :before   => [Time] Fetch activities generated before that datetime (excluding)
    #   :after    => [Time] Fetch activities generated after that datetime (excluding)
    #   :entities => [Hash of Sym => String] Filter by entities values (empty means 'all values')
    #   :only     => [Array of Class] Fetch only those activities
    #   :except   => [Array of Class] Skip those activities
    # @return [Array] An array of Activr::Activity instances
    def count_activities(options = { })
      # default options
      options = {
        :before   => nil,
        :after    => nil,
        :entities => { },
        :only     => [ ],
        :except   => [ ],
      }.merge(options)

      # count
      self.driver.count_activities(options)
    end

    # Insert a new timeline entry
    #
    # @param timeline_entry [Activr::Timeline::Entry] Timeline entry to insert
    # @return The `_id` of the document in collection
    def insert_timeline_entry(timeline_entry)
      # serialize
      timeline_entry_hash = timeline_entry.to_hash

      # run hook
      self.run_hook(:will_insert_timeline_entry, timeline_entry_hash)

      # insert
      self.driver.insert_timeline_entry(timeline_entry.timeline.kind, timeline_entry_hash)
    end

    # Fetch a timeline entry
    #
    # @param timeline    [Activr::Timeline] Timeline instance
    # @param tl_entry_id [String|BSON::ObjectId] Timeline entry id
    # @return [Array] An array of Activr::Timeline::Entry instances
    def fetch_timeline_entry(timeline, tl_entry_id)
      tl_entry_id = ::BSON::ObjectId.from_string(tl_entry_id) if tl_entry_id.is_a?(String)

      # fetch
      timeline_entry_hash = self.driver.find_timeline_entry(timeline.kind, tl_entry_id)
      if timeline_entry_hash
        # run hook
        self.run_hook(:did_fetch_timeline_entry, timeline_entry_hash)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash, timeline)
      else
        nil
      end
    end

    # Fetch timeline entries by descending timestamp
    #
    # @param timeline [Activr::Timeline] Timeline instance
    # @param limit    [Integer] Max number of entries to fetch
    # @param skip     [Integer] Number of entries to skip (default: 0)
    # @return [Array] An array of Activr::Timeline::Entry instances
    def fetch_timeline(timeline, recipient_id, limit, skip = 0)
      # find
      result = self.driver.find_timeline_entries(timeline.kind, timeline.recipient_id, limit, skip).map do |timeline_entry_hash|
        # run hook
        self.run_hook(:did_fetch_timeline_entry, timeline_entry_hash)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash, timeline)
      end

      result
    end

    # Count number of timeline entries
    #
    # @param timeline_kind [String] Timeline kind
    # @param recipient_id  [String] Recipient id
    def count_timeline(timeline_kind, recipient_id)
      self.driver.count_timeline_entries(timeline_kind, recipient_id)
    end


    #
    # Hooks
    #

    # The `will_insert_activity` hook will be run just before inserting
    # an activity document in the database
    #
    # Example:
    #
    #   # insert the 'foo' meta for all activities
    #   Activr.storage.will_insert_activity do |activity_hash|
    #     activity_hash['meta'] ||= { }
    #     activity_hash['meta']['foo'] = 'bar'
    #   end
    #
    def will_insert_activity(&block)
      register_hook(:will_insert_activity, block)
    end

    # The `did_fetch_activity` hook will be run just after fetching
    # an activity document from the database
    #
    # Example:
    #
    #   # ignore the 'foo' meta
    #   Activr.storage.did_fetch_activity do |activity_hash|
    #     if activity_hash['meta']
    #       activity_hash['meta'].delete('foo')
    #     end
    #   end
    #
    def did_fetch_activity(&block)
      register_hook(:did_fetch_activity, block)
    end

    # The `will_insert_timeline_entry` hook will be run just before inserting
    # a timeline entry document in the database
    #
    # Example:
    #
    #   # insert the 'bar' field to all timeline entries documents
    #   Activr.storage.will_insert_timeline_entry do |timeline_entry_hash|
    #     timeline_entry_hash['bar'] = 'baz'
    #   end
    #
    def will_insert_timeline_entry(&block)
      register_hook(:will_insert_timeline_entry, block)
    end

    # The `did_fetch_timeline_entry` hook will be run just after fetching
    # a timeline entry document from the database
    #
    # Example:
    #
    #   # ignore the 'bar' field
    #   Activr.storage.did_fetch_timeline_entry do |timeline_entry_hash|
    #     timeline_entry_hash.delete('bar')
    #   end
    #
    def did_fetch_timeline_entry(&block)
      register_hook(:did_fetch_timeline_entry, block)
    end


    # register a hook
    def register_hook(name, block)
      @hooks[name] ||= [ ]
      @hooks[name] << block
    end

    # get hooks
    #
    # Returns all hooks if name is nil
    def hooks(name = nil)
      name ? (@hooks[name] || [ ]) : @hooks
    end

    # run a hook
    def run_hook(name, *args)
      return if @hooks[name].blank?

      @hooks[name].each do |hook|
        args.any? ? hook.call(*args) : hook.call
      end
    end

    # reset all hooks
    def clear_hooks!
      @hooks = { }
    end

  end # class Storage

end # module Activr
