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
require 'activr/rails'
require 'activr/railtie' if defined?(::Rails)


module Activr

  # access configuration with `Activr.config`
  include Activr::Configuration

  class << self

    attr_accessor :logger


    # configuration sugar
    def configure
      yield self.config
    end

    # setup
    def setup
      self.registry.setup
    end

    # logger
    def logger
      @logger ||= begin
        result = Logger.new(STDOUT)
        result.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} [activr] #{msg}\n"
        end
        result
      end
    end

    # path to activities classes
    def activities_path
      File.join(Activr.config.app_path, "activities")
    end

    # path to timelines classes
    def timelines_path
      File.join(Activr.config.app_path, "timelines")
    end

    # global registry
    #
    # @return [Activr::Registry] Global registry
    def registry
      @registy ||= Activr::Registry.new
    end

    # storage singleton
    #
    # @return [Activr::Storage] Storage instance
    def storage
      @storage ||= Activr::Storage.new
    end

    # dispatcher singleton
    #
    # @return [Activr::Dispatcher] Dispatcher instance
    def dispatcher
      @dispatcher ||= Activr::Dispatcher.new
    end

    # dispatch an activity
    #
    # @param activity [Activr::Activity] Activity instance to dispatch
    # @return The activity id in main activities collection
    def dispatch!(activity)
      # store activity in main collection
      activity.store! unless activity.stored?

      Activr::Async.hook(:route_activity, activity)

      activity
    end

    # helper
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

    # fetch last activities
    #
    # cf. Activr::Storage.fetch_activities
    def activities(limit, options = { })
      options = self._normalize_query_options(options)

      Activr.storage.fetch_activities(limit, options)
    end

    # count total number of activities
    #
    # cf. Activr::Storage.count_activities
    def count_activities(options = { })
      options = self._normalize_query_options(options)

      Activr.storage.count_activities(options)
    end

    # get a timeline
    #
    # @param timeline_class [Class] Timeline class
    # @param recipient [String|Object] Recipient instance or recipient id
    # @return [Activr::Timeline] Timeline instance
    def timeline(timeline_class, recipient)
      timeline_class.new(recipient)
    end

    # render a sentence
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
