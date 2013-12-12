module Activr

  #
  # The Storage is the component that uses the database driver to serialize/unserialize activities and timeline entries.
  #
  # The Storage singleton is accessible with `Activr.storage`
  #
  class Storage

    autoload :MongoDriver, 'activr/storage/mongo_driver'

    # database driver
    attr_reader :driver

    # Init
    def initialize
      @driver = Activr::Storage::MongoDriver.new

      @hooks = { }
    end

    # Is it a valid document id ?
    #
    # @param doc_id [Object] Document id to check
    # @return [true, false]
    def valid_id?(doc_id)
      self.driver.valid_id?(doc_id)
    end

    # Is it a serialized document id ?
    #
    # @return [true,false]
    def serialized_id?(doc_id)
      self.driver.serialized_id?(doc_id)
    end

    # Unserialize a document id
    #
    # @param doc_id [Object] Document id
    # @return [Object] Unserialized document id
    def unserialize_id(doc_id)
      self.driver.unserialize_id(doc_id)
    end

    # Unserialize given parameter only if it is a serialized document id
    #
    # @param doc_id [Object] Document id
    # @return [Object] Unserialized or unmodified document id
    def unserialize_id_if_necessary(doc_id)
      self.serialized_id?(doc_id) ? self.unserialize_id(doc_id) : doc_id
    end

    # Insert a new activity
    #
    # @param activity [Activr::Activity] Activity to insert
    # @return [Object] The inserted activity id
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
    # @param activity_id [Object] Activity id to fetch
    # @return [Activr::Activity, Nil] An activity instance or `nil` if not found
    def fetch_activity(activity_id)
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

    # Fetch latest activities
    #
    # @warning If you use others selectors then 'limit' argument and 'skip' option
    # then you have to setup corresponding indexes in database.
    #
    # @todo Add doc explaining howto setup indexes
    #
    # @param limit [Integer] Max number of activities to fetch
    # @param options [Hash] Options hash
    # @option options [Integer]           :skip     Number of activities to skip (default: 0)
    # @option options [Time]              :before   Fetch activities generated before that datetime (excluding)
    # @option options [Time]              :after    Fetch activities generated after that datetime (excluding)
    # @option options [Hash{Sym=>String}] :entities Filter by entities values (empty means 'all values')
    # @option options [Array<Class>]      :only     Fetch only those activities
    # @option options [Array<Class>]      :except   Skip those activities
    # @return [Array<Activr::Activity>] An array of activities
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
    # @warning If you use one of options' selectors then you have to setup
    # corresponding indexes in database.
    #
    # @todo Add doc explaining howto setup indexes
    #
    # @param options [Hash] Options hash
    # @option options [Time]              :before   Fetch activities generated before that datetime (excluding)
    # @option options [Time]              :after    Fetch activities generated after that datetime (excluding)
    # @option options [Hash{Sym=>String}] :entities Filter by entities values (empty means 'all values')
    # @option options [Array<Class>]      :only     Fetch only those activities
    # @option options [Array<Class>]      :except   Skip those activities
    # @return [Array<Activr::Activity>] An array of activities
    def activities_count(options = { })
      # default options
      options = {
        :before   => nil,
        :after    => nil,
        :entities => { },
        :only     => [ ],
        :except   => [ ],
      }.merge(options)

      # count
      self.driver.activities_count(options)
    end

    # Insert a new timeline entry
    #
    # @param timeline_entry [Activr::Timeline::Entry] Timeline entry to insert
    # @return [Object] Inserted timeline entry id
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
    # @param tl_entry_id [Object]           Timeline entry id
    # @return [Array<Activr::Timeline::Entry>] An array of timeline entries
    def fetch_timeline_entry(timeline, tl_entry_id)
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
    # @return [Array<Activr::Timeline::Entry>] Timeline entries
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
    # @param recipient_id  [Object] Recipient id
    # @return [Intger] Number of timeline entries in given timeline
    def count_timeline(timeline_kind, recipient_id)
      self.driver.count_timeline_entries(timeline_kind, recipient_id)
    end


    #
    # Hooks
    #

    # The `will_insert_activity` hook will be run just before inserting
    # an activity document in the database
    #
    # @example Insert the 'foo' meta for all activities
    #
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
    # @example Ignore the 'foo' meta
    #
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
    # @example Insert the 'bar' field to all timeline entries documents
    #
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
    # @example Ignore the 'bar' field
    #
    #   Activr.storage.did_fetch_timeline_entry do |timeline_entry_hash|
    #     timeline_entry_hash.delete('bar')
    #   end
    #
    def did_fetch_timeline_entry(&block)
      register_hook(:did_fetch_timeline_entry, block)
    end


    # Register a hook
    #
    # @api private
    #
    # @param name  [Symbol] Hook name
    # @param block [Proc]   Hook code
    def register_hook(name, block)
      @hooks[name] ||= [ ]
      @hooks[name] << block
    end

    # Get hooks
    #
    # @api private
    # @note Returns all hooks if `name` is `nil`
    #
    # @param name [Symbol] Hook name
    # @return [Array<Code>] List of hooks
    def hooks(name = nil)
      name ? (@hooks[name] || [ ]) : @hooks
    end

    # Run a hook
    #
    # @api private
    #
    # @param name [Symbol] Hook name
    # @param args [Array]  Hook arguments
    def run_hook(name, *args)
      return if @hooks[name].blank?

      @hooks[name].each do |hook|
        args.any? ? hook.call(*args) : hook.call
      end
    end

    # Reset all hooks
    #
    # @api private
    def clear_hooks!
      @hooks = { }
    end

  end # class Storage

end # module Activr
