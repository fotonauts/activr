module Activr
  class Entity
    module ModelMixin

      extend ActiveSupport::Concern

      included do
        class_attribute :activr_feed_entity_name, :instance_writer => false
        self.activr_feed_entity_name = nil
      end

      module ClassMethods

        #
        # Class interface
        #

        # set a custom entity name to use in activity feed queries
        def activr_feed_entity(name)
          self.activr_feed_entity_name = name.to_sym
        end

      end # module ClassMethods

      # get entity to use for activity feed queries
      def activr_feed_entity
        self.activr_feed_entity_name || Activr::Utils.kind_for_class(self).to_sym
      end

      # fetch activities
      def activities(limit, skip = 0)
        Activr.activities(limit, :skip => skip, self.activr_feed_entity => self.id)
      end

      # get total number of activities
      def activities_count
        Activr.activities_count(self.activr_feed_entity => self.id)
      end

    end # module ModelMixin
  end # class Entity
end # module Activr
