require 'mongo'
require 'uri'

module Activr

  class Storage

    # init
    def initialize
      # check settings
      [ :uri, :collection ].each do |setting|
        raise "Missing setting #{setting} in config: #{self.config.inspect}" if self.config[setting].blank?
      end

      uri = URI.parse(self.config[:uri])

      @db_name = uri.path[1..-1]
      raise "Missing database name in setting uri: #{config[:uri]}" if @db_name.blank?
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
      self.collection.insert(activity_hash)
    end

    # Fetch an activity
    #
    # @param activity_id [String|BSON::ObjectId] Activity id
    # @return [Activr::Activity] An activity instance
    def fetch_activity(activity_id)
      activity_id = ::BSON::ObjectId.from_string(activity_id) if activity_id.is_a?(String)

      # fetch
      activity_hash = self.collection.find_one({ '_id' => activity_id })
      if activity_hash
        # run hook
        Activr.registry.run_hook(:did_fetch_activity, activity_hash)

        # unserialize
        Activr::Activity.from_hash(activity_hash)
      else
        nil
      end
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
      self.timeline_collection(timeline_entry.timeline.kind).insert(timeline_entry_hash)
    end

    # Fetch timeline entries by descending timestamp
    #
    # @param timeline_kind [String] Timeline kind
    # @param recipient_id  [String] Recipient id
    # @param limit         [Integer] Max number of entries to fetch
    # @param skip          [Integer] Number of entries to skip (default: 0)
    # @return [Array] An array of Activr::Timeline::Entry instances
    def fetch_timeline(timeline_kind, recipient_id, limit, skip = 0)
      # compute selector hash
      selector_hash = {
        'tl_kind' => timeline_kind,
        'rcpt'    => recipient_id,
      }

      # compute options hash
      options = {
        :sort  => [ 'at', ::Mongo::DESCENDING ],
        :limit => limit,
        :skip  => skip,
      }

      options[:batch_size] = 100 if (limit > 100)

      # find
      result = self.timeline_collection(timeline_kind).find(selector_hash, options).to_a.map do |timeline_entry_hash|
        # run hook
        Activr.registry.run_hook(:did_fetch_timeline_entry, timeline_entry_hash)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash)
      end

      result
    end


    #
    # Private
    #

    # mongodb connection
    def conn
      @conn ||= ::Mongo::MongoClient.from_uri(self.config[:uri])
    end

    # sugar
    def config
      Activr.config.mongodb
    end

    # handler on main activities collection
    def collection
      @collection ||= self.conn.db(@db_name).collection(self.config[:collection])
    end

    # handler on given timeline collection
    def timeline_collection(timeline_kind)
      @timeline_collections ||= { }
      @timeline_collections[timeline_kind.to_s] ||= self.conn.db(@db_name).collection("#{timeline_kind}_timelines")
    end

  end # class Storage

end # module Activr
