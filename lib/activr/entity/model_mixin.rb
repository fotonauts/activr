module Activr
  class Entity
    module ModelMixin

      extend ActiveSupport::Concern

      included do
        class_attribute :activr_entity_name, :instance_writer => false
        self.activr_entity_name = Activr::Utils.kind_for_class(self).to_sym
      end

      module ClassMethods

        # set a custom entity name to use in activity queries
        def activr_entity(name)
          self.activr_entity_name = name.to_sym
        end

      end # module ClassMethods

      # fetch activities
      def activities(limit, skip = 0)
        Activr.activities(limit, :skip => skip, self.activr_entity_name => self.id)
      end

      # get total number of activities
      def activities_count
        Activr.count_activities(self.activr_entity_name => self.id)
      end

    end # module ModelMixin
  end # class Entity
end # module Activr
