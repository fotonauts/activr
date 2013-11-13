module Activr
  class Registry

    # init
    def initialize
      @timelines        = nil
      @timeline_entries = nil
      @activities       = nil
      @entities         = nil

      @hooks = { }
    end


    #
    # Classes
    #

    # Get all registered timelines
    #
    # returns a hash of:
    # {
    #   <timeline_kind> => <TimelineClass>,
    #   ...
    # }
    def timelines
      @timelines ||= self._classes_from_path(Activr.timelines_path)
    end

    # get class for given timeline
    #
    # @param timeline_kind [Symbol] Timeline kind
    # @return [Class] Timeline class
    def class_for_timeline(timeline_kind)
      result = self.timelines[timeline_kind]
      raise "No class defined for timeline kind: #{timeline_kind}" if result.blank?
      result
    end

    # Get all registered timeline entries
    #
    # returns a hash of:
    # {
    #   <timeline_kind> => {
    #     <route_kind> => <TimelineEntryClass>,
    #     ...
    #   },
    #   ...
    # }
    def timeline_entries
      @timeline_entries ||= begin
        result = { }

        self.timelines.each do |(timeline_kind, timeline_class)|
          dir_path = File.join(Activr.timelines_path, timeline_kind)
          dir_path = File.directory?(dir_path) ? dir_path : File.join(Activr.timelines_path, "#{timeline_kind}_timeline")

          if File.directory?(dir_path)
            result[timeline_kind] = { }

            Dir["#{dir_path}/*.rb"].sort.inject(result[timeline_kind]) do |memo, file_path|
              base_name = File.basename(file_path, '.rb')
              klass = "#{timeline_class.name}::#{base_name.camelize}".constantize

              route_kind = if (match_data = base_name.match(/(.+)_timeline_entry$/))
                match_data[1]
              else
                base_name
              end

              route = timeline_class.routes.find do |timeline_route|
                timeline_route.kind == route_kind
              end

              raise "Timeline entry class found for an unspecified timeline route: #{file_path} / routes: #{timeline_class.routes.inspect}" unless route
              memo[route_kind] = klass

              memo
            end
          end
        end

        result
      end
    end

    # get class for timeline entry correspond to given route in given timeline
    #
    # @param timeline_kind [Symbol] Timeline kind
    # @param route_kind [Symbol] Route kind
    # @return [Class] Timeline entry class
    def class_for_timeline_entry(timeline_kind, route_kind)
      (self.timeline_entries[timeline_kind] && self.timeline_entries[timeline_kind][route_kind]) || Activr::Timeline::Entry
    end

    # Get all registered activities
    #
    # returns a hash of:
    # {
    #   <activity_kind> => <ActivityClass>,
    #   ...
    # }
    def activities
      @activities ||= self._classes_from_path(Activr.activities_path)
    end

    # get class for given activity
    #
    # @param activity_kind [Symbol] Activity kind
    # @return [Class] Activity class
    def class_for_activity(activity_kind)
      result = self.activities[activity_kind]
      raise "No class defined for activity kind: #{activity_kind}" if result.blank?
      result
    end

    # Get all registered entities
    #
    # returns a hash of:
    # {
    #   :<entity_name> => [ <ActivityClass>, <ActivityClass>, ... ],
    #   ...
    # }
    def entities
      # loading activities triggers calls to #add_entity method
      self.activities if @entities.blank?

      @entities
    end

    # Register an entity
    #
    # @param entity_name    [Symbole] Entity name
    # @param activity_klass [Class]   Activity class that uses that entity
    def add_entity(entity_name, activity_klass)
      @entities ||= { }
      @entities[entity_name] ||= [ ]
      @entities[entity_name] << activity_klass
    end

    # helper
    def _classes_from_path(dir_path)
      Dir["#{dir_path}/*.rb"].sort.inject({ }) do |memo, file_path|
        klass = File.basename(file_path, '.rb').camelize.constantize
        memo[klass.kind] = klass

        memo
      end
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
    #   Activr.will_insert_activity do |activity_hash|
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
    #   Activr.did_fetch_activity do |activity_hash|
    #     if activity_hash['meta']
    #       activity_hash['meta'].delete('foo')
    #     end
    #   end
    #
    def did_fetch_activity(&block)
      register_hook(:did_fetch_activity, block)
    end

    # The `will_insert_activity` hook will be run just before inserting
    # a timeline entry document in the database
    #
    # Example:
    #
    #   # insert the 'bar' field to all timeline entries documents
    #   Activr.will_insert_timeline_entry do |timeline_entry_hash|
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
    #   Activr.did_fetch_timeline_entry do |timeline_entry_hash|
    #     timeline_entry_hash.delete('bar')
    #   end
    #
    # @todo Use that !
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

  end # class Registry
end # module Activr
