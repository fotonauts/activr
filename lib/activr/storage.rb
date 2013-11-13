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
