require 'rubygems'

require 'mustache'
require 'fwissr'

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

require 'activr/railtie' if defined?(Rails)


module Activr

  # access configuration with `Activr.config`
  include Activr::Configuration

  class << self

    # configuration sugar
    def configure
      yield self.config
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

      if Activr.config.sync
        self.dispatcher.route(activity)
      else
        # @todo !!!
        raise "not implemented"
      end

      activity
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
