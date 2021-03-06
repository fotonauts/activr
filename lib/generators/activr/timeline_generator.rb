module Activr
  # Rails generators
  module Generators

    # Generates a {Timeline} subclass in your Rails application
    class TimelineGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path("../templates", __FILE__)

      check_class_collision :suffix => "Timeline"

      desc "Creates a Timeline class"
      # class_option :recipient, :required => true, :type => :string, :desc => "Recipient class"
      argument :recipient_class, :type => :string

      # Create the timeline class file
      #
      # @api private
      def create_timeline_files
        template "timeline.rb", "#{Activr.config.app_path}/timelines/#{file_name}_timeline.rb"
      end
    end

  end
end
