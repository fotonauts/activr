require 'rubygems'

require 'mustache'
require 'fwissr'

require 'logger'

# active support
require 'active_support/callbacks'
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


#
# Manage activity feeds
#
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
    # @yield [Configuration] Configuration singleton
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

    # {Registry} singleton
    #
    # @return [Registry] {Registry} instance
    def registry
      @registy ||= Activr::Registry.new
    end

    # {Storage} singleton
    #
    # @return [Storage] {Storage} instance
    def storage
      @storage ||= Activr::Storage.new
    end

    # {Dispatcher} singleton
    #
    # @return [Dispatcher] {Dispatcher} instance
    def dispatcher
      @dispatcher ||= Activr::Dispatcher.new
    end

    # Dispatch an activity
    #
    # @param activity [Activity] Activity instance to dispatch
    # @param options [Hash] Options hash
    # @option options [Integer] :skip_dup_period Activity is skipped if a duplicate one is found in that period of time, in seconds (default: nil)
    # @return [Activity] The activity
    def dispatch!(activity, options = { })
      # default options
      options = {
        :skip_dup_period => nil,
      }.merge(options)

      # check for duplicates
      skip_it = options[:skip_dup_period] && (options[:skip_dup_period] > 0) &&
                (Activr.storage.count_duplicate_activities(activity, Time.now - options[:skip_dup_period]) > 0)

      if !skip_it
        if !activity.stored?
          # store activity in main collection
          activity.store!
        end

        # check if storing failed
        if activity.stored?
          Activr::Async.hook(:route_activity, activity)
        end
      end

      activity
    end

    # Normalize query options
    #
    # @api private
    #
    # @param options [Hash] Options to normalize
    # @return [Hash] Normalized options
    def normalize_query_options(options)
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

    # (see Storage#find_activities)
    def activities(limit, options = { })
      options = self.normalize_query_options(options)

      Activr.storage.find_activities(limit, options)
    end

    # (see Storage#count_activities)
    def activities_count(options = { })
      options = self.normalize_query_options(options)

      Activr.storage.count_activities(options)
    end

    # Get a timeline instance
    #
    # @param timeline_class [Class] Timeline class
    # @param recipient [String|Object] Recipient instance or recipient id
    # @return [Timeline] Timeline instance
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
