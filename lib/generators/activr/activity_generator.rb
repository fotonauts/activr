module Activr
  module Generators

    class ActivityGenerator < Rails::Generators::NamedBase
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
          raise "Erroneous entity argument: #{str}" unless (ary.size == 2)

          {
            :name  => ary[0].underscore,
            :class => ary[1].camelize,
          }
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
            result += " {{#{entity[:name]}}}"
          end
        end

        result
      end
    end

  end
end
