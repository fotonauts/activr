module Activr

  #
  # The registry holds all activities, entities, timelines and timeline entries classes defined in the application
  #
  # The registry singleton is accessible with {Activr.registry}
  #
  class Registry

    # @return [Hash{Symbol=>Class}] model class associated to entity name
    attr_reader :entity_classes

    # @return [Hash{Class=>Array<Symbol>}] entity names for activity class
    attr_reader :activity_entities

    # Init
    def initialize
      self.reset
    end

    # Reset registry
    def reset
      @timelines         = nil
      @timeline_entries  = nil
      @activities        = nil
      @entities          = nil
      @models            = nil

      @entity_classes    = { }
      @activity_entities = { }

      @timeline_entities_for_model = { }
      @activity_entities_for_model = { }
    end

    # Setup registry
    def setup
      self.reset

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
    # @return [Hash{String=>Class}] A hash of `<timeline kind> => <timeline class>`
    def timelines
      @timelines ||= self.classes_from_path(Activr.timelines_path)
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
    # @return [Hash{String=>Hash{String=>Class}}] A hash of `<timeline kind> => { <route kind> => <timeline entry class>, ... }`
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
    # @return [Hash{String=>Class}] A hash of `<activity kind> => <activity class>`
    def activities
      @activities ||= self.classes_from_path(Activr.activities_path)
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
    # @return [Hash{Symbol=>Array<Class>}] A hash of `:<entity name> => [ <activity class>, <activity class>, ... ]`
    def entities
      # loading activities triggers calls to #add_entity method
      self.activities if @entities.blank?

      @entities || { }
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
    # @param entity_options [Hash]   Entity options
    # @param activity_klass [Class]  Activity class that uses that entity
    def add_entity(entity_name, entity_options, activity_klass)
      entity_name = entity_name.to_sym

      if @entity_classes[entity_name] && (@entity_classes[entity_name] != entity_options[:class])
        # otherwise this would break timeline entries deletion mecanism
        raise "Entity name #{entity_name} already used with class #{@entity_classes[entity_name]}, can't redefine it with class #{entity_options[:class]}"
      end

      # class for entity
      @entity_classes[entity_name] = entity_options[:class]

      # entities for activity
      @activity_entities[activity_klass] ||= [ ]
      @activity_entities[activity_klass] << entity_name

      # entities
      @entities ||= { }
      @entities[entity_name] ||= { }

      if !@entities[entity_name][activity_klass].blank?
        raise "Entity name #{entity_name} already used for activity: #{activity_klass}"
      end

      @entities[entity_name][activity_klass] = entity_options
    end

    # Get all models that included mixin {Activr::Entity::ModelMixin}
    #
    # @return [Array<Class>] List of model classes
    def models
      # loading activities triggers models loading
      self.activities if @models.blank?

      @models || [ ]
    end

    # Register a model
    #
    # @param model_class [Class] Model class
    def add_model(model_class)
      @models ||= [ ]
      @models << model_class
    end

    # Get all entities names for given model class
    def activity_entities_for_model(model_class)
      @activity_entities_for_model[model_class] ||= begin
        result = [ ]

        @entity_classes.each do |entity_name, entity_class|
          result << entity_name if (entity_class == model_class)
        end

        result
      end
    end

    # Get all entities names by timelines that can have a reference to given model class
    #
    # @param model_class [Class] Model class
    # @return [Hash{Class=>Array<Symbol>}] Lists of entities names indexed by timeline class
    def timeline_entities_for_model(model_class)
      @timeline_entities_for_model[model_class] ||= begin
        result = { }

        self.timelines.each do |timeline_kind, timeline_class|
          result[timeline_class] = [ ]

          timeline_class.routes.each do |route|
            entities_ary = @activity_entities[route.activity_class]
            (entities_ary || [ ]).each do |entity_name|
              result[timeline_class] << entity_name if (@entity_classes[entity_name] == model_class)
            end
          end

          result[timeline_class].uniq!
        end

        result
      end
    end

    # Find all classes in given directory
    #
    # @api private
    #
    # @param dir_path [String] Directory path
    # @return [Hash{String=>Class}] Hash of `<kind> => <Class>`
    def classes_from_path(dir_path)
      Dir["#{dir_path}/*.rb"].sort.inject({ }) do |memo, file_path|
        require(file_path)

        klass = File.basename(file_path, '.rb').camelize.constantize

        if !memo[klass.kind].nil?
          raise "Kind #{klass.kind} already used by class #{memo[klass.kind]} so can't use it for class #{klass}"
        end

        memo[klass.kind] = klass

        memo
      end
    end

  end # class Registry

end # module Activr
