module Activr
  module Generators

    class ActivityGenerator < ::Rails::Generators::NamedBase
      DEFAULT_ENTITY_FIELD = :name

      source_root File.expand_path("../templates", __FILE__)

      check_class_collision :suffix => "Activity"

      argument :entities, :type => :array, :default => [], :banner => "entity[:class] entity[:class]"
      class_option :full, type: :boolean, :desc => "Generate full class"

      desc "Creates an Activity class"

      def create_activity_file
        template "activity.rb", "app/activities/#{file_name}_activity.rb"
      end

      def entities_infos
        entities.map do |str|
          ary = str.split(':')

          name = ary[0].underscore

          klass, set_klass = if ary[1]
            [ ary[1].camelize, true ]
          else
            [ ary[0].camelize, false ]
          end

          human_meth = _resolve_entity_field(klass)

          result = {
            :name     => name,
            :humanize => human_meth,
          }

          result[:class] = klass if set_klass

          result
        end
      end

      def humanization
        result = ""

        actor = entities_infos.find{ |entity| entity[:name] == 'actor' }
        if actor
          result += "{{actor}} "
        end

        result += name.underscore.gsub('_', ' ')

        entities_infos.each do |entity|
          if entity[:name] != 'actor'
            result += " {{{#{entity[:name]}}}}"
          end
        end

        result
      end

      private

      def _resolve_entity_field(entity_klass)
        klass = entity_klass.constantize

        field = [ :fullname, :name, :title ].find do |meth_name|
          klass.method_defined?(meth_name)
        end

        field || DEFAULT_ENTITY_FIELD
      end
    end

  end
end
