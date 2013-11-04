module Activr

  class Registry

    attr_reader :entities, :activities, :timelines, :timeline_entries

    # init
    def initialize
      @entities   = [ ]
      @activities = [ ]
      @timelines  = [ ]
      @timeline_entries = [ ]
    end

    def add_entity(entity_name)
      @entities << entity_name unless @entities.include?(entity_name)
    end

    def add_activity(activity_class)
      @activities << activity_class unless @activities.include?(activity_class)
    end

    def add_activities_for_path(dir_path)
      # @todo !!!
      raise "not implemented"
    end

    def add_timeline(timeline_class)
      @timelines << timeline_class unless @timelines.include?(timeline_class)
    end

    def add_timelines_for_path(dir_path)
      # @todo !!!
      raise "not implemented"
    end

    def add_timeline_entry(timeline_entry_class)
      @timeline_entries << timeline_entry_class unless @timeline_entries.include?(timeline_entry_class)
    end

    def add_timeline_entries_for_path(dir_path)
      # @todo !!!
      raise "not implemented"
    end

  end # class Registry

end # module Activr
