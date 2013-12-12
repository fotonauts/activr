require 'rubygems'

require 'mustache'
require 'fwissr'

require 'logger'

# active support
require 'active_support/core_ext/class'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'active_support/concern'
require 'active_support/configurable'

# active model
require 'active_model/callbacks'

# activr
require 'activr/version'
require 'activr/utils'
require 'activr/configuration'
require 'activr/storage'
require 'activr/registry'
require 'activr/entity'
require 'activr/activity'
require 'activr/timeline'
require 'activr/dispatcher'
require 'activr/async'
require 'activr/rails_ctx'
require 'activr/railtie' if defined?(::Rails)


module Activr

  # Access configuration with `Activr.config`
  include Activr::Configuration

  class << self

    attr_writer :logger


    # Configuration sugar
    #
    # @example
    #   Activr.configure do |config|
    #     config.app_path      = File.join(File.dirname(__FILE__), "app")
    #     config.mongodb[:uri] = "mongodb://#{rspec_mongo_host}:#{rspec_mongo_port}/#{rspec_mongo_db}"
    #   end
    #
    # @yield [Activr::Configuration] Configuration singleton
    def configure
      yield self.config
    end

    # Setup registry
    def setup
      self.registry.setup
    end

    # @return [Logger] A logger instance
    def logger
      @logger ||= begin
        result = Logger.new(STDOUT)
        result.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} [activr] #{msg}\n"
        end
        result
      end
    end

    # Path to activities classes directory
    #
    # @return [String] Directory path
    def activities_path
      File.join(Activr.config.app_path, "activities")
    end

    # Path to timelines classes directory
    #
    # @return [String] Directory path
    def timelines_path
      File.join(Activr.config.app_path, "timelines")
    end

    # {Activr::Registry} singleton
    #
    # @return [Activr::Registry] Registry instance
    def registry
      @registy ||= Activr::Registry.new
    end

    # {Activr::Storage} singleton
    #
    # @return [Activr::Storage] Storage instance
    def storage
      @storage ||= Activr::Storage.new
    end

    # {Activr::Dispatcher} singleton
    #
    # @return [Activr::Dispatcher] Dispatcher instance
    def dispatcher
      @dispatcher ||= Activr::Dispatcher.new
    end

    # Dispatch an activity
    #
    # @param activity [Activr::Activity] Activity instance to dispatch
    # @return [Object] The activity id in main activities collection
    def dispatch!(activity)
      # store activity in main collection
      activity.store! unless activity.stored?

      Activr::Async.hook(:route_activity, activity)

      activity
    end

    # Normalize query options
    #
    # @api private
    #
    # @param options [Hash] Options to normalize
    # @return [Hash] Normalized options
    def _normalize_query_options(options)
      result = { }

      options.each do |key, value|
        key = key.to_sym

        if Activr.registry.entities_names.include?(key)
          # extract entities from options
          result[:entities] ||= { }
          result[:entities][key] = value
        else
          result[key] = value
        end
      end

      result
    end

    # Fetch last activities
    #
    # @see Activr::Storage#fetch_activities
    #
    # @param (see Activr::Storage#fetch_activities)
    def activities(limit, options = { })
      options = self._normalize_query_options(options)

      Activr.storage.fetch_activities(limit, options)
    end

    # Count total number of activities
    #
    # @see Activr::Storage#activities_count
    #
    # @param (see Activr::Storage#activities_count)
    def activities_count(options = { })
      options = self._normalize_query_options(options)

      Activr.storage.activities_count(options)
    end

    # Get a timeline instance
    #
    # @param timeline_class [Class] Timeline class
    # @param recipient [String|Object] Recipient instance or recipient id
    # @return [Activr::Timeline] Timeline instance
    def timeline(timeline_class, recipient)
      timeline_class.new(recipient)
    end

    # Render a sentence
    #
    # @param text     [String] Sentence to render
    # @param bindings [Hash] Sentence bindings
    # @return [String] Rendered sentence
    def sentence(text, bindings = { })
      # render
      result = Activr::Utils.render_mustache(text, bindings)

      # strip whitespaces
      result.strip!

      result
    end

  end # class << self

end # module Activr
