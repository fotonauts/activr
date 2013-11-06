module Activr
  class Registry

    # init
    def initialize
      @timelines  = nil
      @activities = nil
      @entities   = nil
    end

    # Get all registered timelines
    #
    # returns a hash of:
    # {
    #   :<timeline_kind> => <TimelineClass>,
    #   ...
    # }
    def timelines
      @timelines ||= self._classes_from_path(Activr.timelines_path)
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


    #
    # Private
    #

    def _classes_from_path(dir_path)
      Dir["#{dir_path}/*.rb"].sort.inject({ }) do |memo, file_path|
        klass = File.basename(file_path, '.rb').camelize.constantize
        memo[klass.kind] = klass

        memo
      end
    end

  end # class Registry
end # module Activr
