module Activr

  #
  # The storage is the component that uses the database driver to serialize/unserialize activities and timeline entries.
  #
  # The storage singleton is accessible with {Activr.storage}
  #
  class Storage

    autoload :MongoDriver, 'activr/storage/mongo_driver'

    # @return [MongoDriver] database driver
    attr_reader :driver

    def initialize
      @driver = Activr::Storage::MongoDriver.new

      @hooks = { }
    end

    # Is it a valid document id
    #
    # @param doc_id [Object] Document id to check
    # @return [true, false]
    def valid_id?(doc_id)
      self.driver.valid_id?(doc_id)
    end

    # Is it a serialized document id
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


    #
    # Activities
    #

    # Insert a new activity
    #
    # @param activity [Activity] Activity to insert
    # @return [Object] The inserted activity id
    def insert_activity(activity)
      # serialize
      activity_hash = activity.to_hash

      # run hook
      self.run_hook(:will_insert_activity, activity_hash)

      # insert
      self.driver.insert_activity(activity_hash)
    end

    # Find an activity
    #
    # @param activity_id [Object] Activity id to find
    # @return [Activity, Nil] An activity instance or `nil` if not found
    def find_activity(activity_id)
      activity_hash = self.driver.find_activity(activity_id)
      if activity_hash
        # run hook
        self.run_hook(:did_find_activity, activity_hash)

        # unserialize
        Activr::Activity.from_hash(activity_hash)
      else
        nil
      end
    end

    # Find latest activities
    #
    # @note If you use others selectors then 'limit' argument and 'skip' option then you have to setup corresponding indexes in database.
    #
    # @todo Add doc explaining howto setup indexes
    #
    # @param limit [Integer] Max number of activities to find
    # @param options [Hash] Options hash
    # @option options [Integer]           :skip     Number of activities to skip (default: 0)
    # @option options [Time]              :before   Find activities generated before that datetime (excluding)
    # @option options [Time]              :after    Find activities generated after that datetime (excluding)
    # @option options [Hash{Sym=>String}] :entities Filter by entities values (empty means 'all values')
    # @option options [Array<Class>]      :only     Find only these activities
    # @option options [Array<Class>]      :except   Skip these activities
    # @return [Array<Activity>] An array of activities
    def find_activities(limit, options = { })
      # default options
      options = {
        :skip     => 0,
        :before   => nil,
        :after    => nil,
        :entities => { },
        :only     => [ ],
        :except   => [ ],
      }.merge(options)

      options[:only] = [ options[:only] ] if (options[:only] && !options[:only].is_a?(Array))

      # find
      result = self.driver.find_activities(limit, options).map do |activity_hash|
        # run hook
        self.run_hook(:did_find_activity, activity_hash)

        # unserialize
        Activr::Activity.from_hash(activity_hash)
      end

      result
    end

    # Count number of activities
    #
    # @note If you use one of options selectors then you have to setup corresponding indexes in database.
    #
    # @todo Add doc explaining howto setup indexes
    #
    # @param options [Hash] Options hash
    # @option options [Time]              :before   Find activities generated before that datetime (excluding)
    # @option options [Time]              :after    Find activities generated after that datetime (excluding)
    # @option options [Hash{Sym=>String}] :entities Filter by entities values (empty means 'all values')
    # @option options [Array<Class>]      :only     Find only these activities
    # @option options [Array<Class>]      :except   Skip these activities
    # @return [Integer] Number of activities
    def count_activities(options = { })
      # default options
      options = {
        :before   => nil,
        :after    => nil,
        :entities => { },
        :only     => [ ],
        :except   => [ ],
      }.merge(options)

      options[:only] = [ options[:only] ] if (options[:only] && !options[:only].is_a?(Array))

      # count
      self.driver.count_activities(options)
    end

    # Delete activities referring to given entity model instance
    #
    # @param model [Object] Model instance
    def delete_activities_for_entity_model(model)
      Activr.registry.activity_entities_for_model(model.class).each do |entity_name|
        self.driver.delete_activities(entity_name => model.id)
      end
    end


    #
    # Timeline Entries
    #

    # Insert a new timeline entry
    #
    # @param timeline_entry [Timeline::Entry] Timeline entry to insert
    # @return [Object] Inserted timeline entry id
    def insert_timeline_entry(timeline_entry)
      # serialize
      timeline_entry_hash = timeline_entry.to_hash

      # run hook
      self.run_hook(:will_insert_timeline_entry, timeline_entry_hash, timeline_entry.timeline.class)

      # insert
      self.driver.insert_timeline_entry(timeline_entry.timeline.kind, timeline_entry_hash)
    end

    # Find a timeline entry
    #
    # @param timeline    [Timeline] Timeline instance
    # @param tl_entry_id [Object]   Timeline entry id
    # @return [Timeline::Entry, Nil] Found timeline entry
    def find_timeline_entry(timeline, tl_entry_id)
      timeline_entry_hash = self.driver.find_timeline_entry(timeline.kind, tl_entry_id)
      if timeline_entry_hash
        # run hook
        self.run_hook(:did_find_timeline_entry, timeline_entry_hash, timeline.class)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash, timeline)
      else
        nil
      end
    end

    # Find timeline entries by descending timestamp
    #
    # @param timeline [Timeline] Timeline instance
    # @param limit    [Integer]  Max number of entries to find
    # @param options  [Hash]     Options hash
    # @option options [Integer]                :skip Number of entries to skip (default: 0)
    # @option options [Array<Timeline::Route>] :only An array of routes to fetch
    # @return [Array<Timeline::Entry>] An array of timeline entries
    def find_timeline(timeline, limit, options = { })
      options = {
        :skip => 0,
        :only => [ ],
      }.merge(options)

      options[:only] = [ options[:only] ] if (options[:only] && !options[:only].is_a?(Array))

      result = self.driver.find_timeline_entries(timeline.kind, timeline.recipient_id, limit, options).map do |timeline_entry_hash|
        # run hook
        self.run_hook(:did_find_timeline_entry, timeline_entry_hash, timeline.class)

        # unserialize
        Activr::Timeline::Entry.from_hash(timeline_entry_hash, timeline)
      end

      result
    end

    # Count number of timeline entries
    #
    # @param timeline [Timeline] Timeline instance
    # @param options  [Hash]     Options hash
    # @option options [Array<Timeline::Route>] :only An array of routes to count
    # @return [Integer] Number of timeline entries in given timeline
    def count_timeline(timeline, options = { })
      options = {
        :only => [ ],
      }.merge(options)

      options[:only] = [ options[:only] ] if (options[:only] && !options[:only].is_a?(Array))

      self.driver.count_timeline_entries(timeline.kind, timeline.recipient_id, options)
    end

    # Delete timeline entries referring to given entity model instance
    #
    # @param model [Object] Model instance
    def delete_timeline_entries_for_entity_model(model)
      Activr.registry.timeline_entities_for_model(model.class).each do |timeline_class, entities|
        entities.each do |entity_name|
          self.driver.delete_timeline_entries(timeline_class.kind, "activity.#{entity_name}" => model.id)
        end
      end
    end


    #
    # Indexes
    #

    # Add index for activities
    #
    # @param index [String,Array<String>] Field or array of fields
    # @param options [Hash] Options hash
    # @option options (see Activr::Storage::MongoDriver#add_index)
    # @return [String] Index created
    def add_activity_index(index, options = { })
      self.driver.add_activity_index(index, options)
    end

    # Add index for timeline entries
    #
    # @param timeline_kind [String] Timeline kind
    # @param index         [String,Array<String>] Field or array of fields
    # @param options [Hash] Options hash
    # @option options (see Activr::Storage::MongoDriver#add_index)
    # @return [String] Index created
    def add_timeline_index(timeline_kind, index, options = { })
      self.driver.add_timeline_index(timeline_kind, index, options)
    end

    # Ensure all necessary indexes
    #
    # @yield [String] Created index name
    def create_indexes
      # Create indexes on 'activities' collection for models that includes Activr::Entity::ModelMixin
      #
      # eg: activities
      #   [['actor', Mongo::ASCENDING], ['at', Mongo::ASCENDING]]
      #   [['album', Mongo::ASCENDING], ['at', Mongo::ASCENDING]]
      #   [['picture', Mongo::ASCENDING], ['at', Mongo::ASCENDING]]
      Activr.registry.models.each do |model_class|
        if !model_class.activr_entity_settings[:feed_index]
          # @todo Output a warning to remove the index if it exists
        else
          fields = [ model_class.activr_entity_feed_actual_name.to_s, 'at' ]

          index_name = Activr.storage.add_activity_index(fields)
          yield("activity / #{index_name}") if block_given?
        end
      end

      # Create indexes on '*_timelines' collections for defined timeline classes
      #
      # eg: user_news_feed_timelines
      #   [['rcpt', Mongo::ASCENDING], ['activity.at', Mongo::ASCENDING]]
      Activr.registry.timelines.each do |timeline_kind, timeline_class|
        fields = [ 'rcpt', 'activity.at' ]

        index_name = Activr.storage.add_timeline_index(timeline_kind, fields)
        yield("#{timeline_kind} timeline / #{index_name}") if block_given?
      end

      # Create sparse indexes to remove activities and timeline entries when entity is deleted
      #
      # eg: activities
      #   [['actor', Mongo::ASCENDING]], :sparse => true
      #
      # eg: user_news_feed_timelines
      #   [['activity.actor', Mongo::ASCENDING]], :sparse => true
      #   [['activity.album', Mongo::ASCENDING]], :sparse => true
      #   [['activity.picture', Mongo::ASCENDING]], :sparse => true
      Activr.registry.models.each do |model_class|
        if model_class.activr_entity_settings[:deletable]
          # create sparse index on `activities`
          Activr.registry.activity_entities_for_model(model_class).each do |entity_name|
            # if entity activity feed is enabled and this is the entity name used to fetch that feed then we can use the existing index...
            if !model_class.activr_entity_settings[:feed_index] || (entity_name != model_class.activr_entity_feed_actual_name)
              # ... else we create an index
              index_name = Activr.storage.add_activity_index(entity_name.to_s, :sparse => true)
              yield("activity / #{index_name}") if block_given?
            end
          end

          # create sparse index on timeline classes where that entity can be present
          Activr.registry.timeline_entities_for_model(model_class).each do |timeline_class, entities|
            entities.each do |entity_name|
              index_name = Activr.storage.add_timeline_index(timeline_class.kind, "activity.#{entity_name}", :sparse => true)
              yield("#{timeline_class.kind} timeline / #{index_name}") if block_given?
            end
          end
        end
      end
    end


    #
    # Hooks
    #

    # Hook: run just before inserting an activity document in the database
    #
    # @example Insert the 'foo' meta into all activities
    #
    #   Activr.storage.will_insert_activity do |activity_hash|
    #     activity_hash['meta'] ||= { }
    #     activity_hash['meta']['foo'] = 'bar'
    #   end
    #
    def will_insert_activity(&block)
      register_hook(:will_insert_activity, block)
    end

    # Hook: run just after fetching an activity document from the database
    #
    # @example Ignore the 'foo' meta
    #
    #   Activr.storage.did_find_activity do |activity_hash|
    #     if activity_hash['meta']
    #       activity_hash['meta'].delete('foo')
    #     end
    #   end
    #
    def did_find_activity(&block)
      register_hook(:did_find_activity, block)
    end

    # Hook: run just before inserting a timeline entry document in the database
    #
    # @example Insert the 'bar' field into all timeline entries documents
    #
    #   Activr.storage.will_insert_timeline_entry do |timeline_entry_hash, timeline_class|
    #     timeline_entry_hash['bar'] = 'baz'
    #   end
    #
    def will_insert_timeline_entry(&block)
      register_hook(:will_insert_timeline_entry, block)
    end

    # Hook: run just after fetching a timeline entry document from the database
    #
    # @example Ignore the 'bar' field
    #
    #   Activr.storage.did_find_timeline_entry do |timeline_entry_hash, timeline_class|
    #     timeline_entry_hash.delete('bar')
    #   end
    #
    def did_find_timeline_entry(&block)
      register_hook(:did_find_timeline_entry, block)
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
    # @return [Array<Proc>] List of hooks
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
