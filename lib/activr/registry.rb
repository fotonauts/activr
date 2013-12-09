module Activr

  #
  # The Registry holds all activities, entities, timelines and timeline entries classes defined in the application
  #
  # The Registry singleton is accessible with `Activr.registry`
  #
  class Registry

    # Init
    def initialize
      @timelines        = nil
      @timeline_entries = nil
      @activities       = nil
      @entities         = nil
    end

    # Setup registry
    def setup
      # eagger load all classes
      self.activities
      self.timelines
      self.timeline_entries
    end


    #
    # Classes
    #

    # Get all registered timelines
    #
    # @return [Hash{String=>Class}] A hash of `<timeline_kind> => <TimelineClass>`
    def timelines
      @timelines ||= self._classes_from_path(Activr.timelines_path)
    end

    # Get class for given timeline kind
    #
    # @param timeline_kind [String] Timeline kind
    # @return [Class] Timeline class
    def class_for_timeline(timeline_kind)
      result = self.timelines[timeline_kind]
      raise "No class defined for timeline kind: #{timeline_kind}" if result.blank?
      result
    end

    # Get all registered timeline entries
    #
    # @return [Hash{String=>Hash{String=>Class}}] A hash of `<timeline_kind> => { <route_kind> => <TimelineEntryClass>, ... }`
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

    # Get class for timeline entry corresponding to given route in given timeline
    #
    # @param timeline_kind [String] Timeline kind
    # @param route_kind    [String] Route kind
    # @return [Class] Timeline entry class
    def class_for_timeline_entry(timeline_kind, route_kind)
      (self.timeline_entries[timeline_kind] && self.timeline_entries[timeline_kind][route_kind]) || Activr::Timeline::Entry
    end

    # Get all registered activities
    #
    # @return [Hash{String=>Class}] A hash of `<activity_kind> => <ActivityClass>`
    def activities
      @activities ||= self._classes_from_path(Activr.activities_path)
    end

    # Get class for given activity
    #
    # @param activity_kind [String] Activity kind
    # @return [Class] Activity class
    def class_for_activity(activity_kind)
      result = self.activities[activity_kind]
      raise "No class defined for activity kind: #{activity_kind}" if result.blank?
      result
    end

    # Get all registered entities
    #
    # @return [Hash{Symbol=>Array<ActivityClass>}] A hash of `:<entity_name> => [ <ActivityClass>, <ActivityClass>, ... ]`
    def entities
      # loading activities triggers calls to #add_entity method
      self.activities if @entities.blank?

      @entities
    end

    # Get all registered entities names
    #
    # @return [Array<Symbol>] List of entities names
    def entities_names
      @entities_names ||= self.entities.keys
    end

    # Register an entity
    #
    # @param entity_name    [Symbol] Entity name
    # @param activity_klass [Class]  Activity class that uses that entity
    def add_entity(entity_name, activity_klass)
      @entities ||= { }
      @entities[entity_name] ||= [ ]
      @entities[entity_name] << activity_klass
    end

    # Find all classes in given directory
    #
    # @api private
    #
    # @param dir_path [String] Directory path
    # @return [Hash{String=>Class}] Hash of `<kind> => <Class>`
    def _classes_from_path(dir_path)
      Dir["#{dir_path}/*.rb"].sort.inject({ }) do |memo, file_path|
        klass = File.basename(file_path, '.rb').camelize.constantize
        memo[klass.kind] = klass

        memo
      end
    end

  end # class Registry

end # module Activr
