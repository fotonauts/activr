require 'rubygems'

require 'mustache'
require 'mongo'

# activesupport
require 'active_support/core_ext/class'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'

# activr
require 'activr/version'
require 'activr/utils'
require 'activr/registry'
require 'activr/entity'
require 'activr/activity'
require 'activr/timeline'


module Activr

  class << self

    # global registry
    #
    # @return [Activr::Registry] Global registry
    def registry
      @registy ||= Activr::Registry.new
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
