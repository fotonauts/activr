module Activr
  class Entity

    autoload :ModelMixin, 'activr/entity/model_mixin'

    attr_reader :name, :options, :activity
    attr_reader :model_class, :model_id


    # @param name    [String] Entity name
    # @param value   [Object|String] Entity value of entity id
    # @param options [Hash] Options hash:
    #   :class => [String] Entity class
    #   :activity => [Activr::Activity] The 'master' activity
    def initialize(name, value, options = { })
      @name = name
      @options = options.dup

      @activity    = @options.delete(:activity)
      @model_class = @options.delete(:class)

      if self._is_valid_id?(value)
        @model_id = value

        raise "Missing :class option: #{options.inspect}" if @model_class.blank?
        raise "Model class MUST implement #find method" unless @model_class.respond_to?(:find)
      else
        @model = value

        if (@model_class && (@model_class != @model.class))
          raise "Model class mismatch: #{@model_class} != #{@model.class}"
        end

        @model_class ||= @model.class
        @model_id = @model.id
      end
    end

    # memoized model
    def model
      @model ||= self.model_class.find(self.model_id)
    end

    # humanize entity
    def humanize(options = { })
      result = nil

      options_handled = false

      result = if !@options[:humanize].blank?
        case self.model.method(@options[:humanize]).arity
        when 1
          options_handled = true
          result = self.model.__send__(@options[:humanize], options)
        else
          result = self.model.__send__(@options[:humanize])
        end
      else
        ""
      end

      if result.blank? && @options[:default]
        result = @options[:default]
      end

      if !result.blank? && !options_handled
        # @todo handle options
      end

      result
    end


    #
    # Private
    #

    # helper
    def _is_valid_id?(value)
      value.is_a?(String) || (defined?(::BSON) && value.is_a?(::BSON::ObjectId))
    end

  end # class Entity
end # module Activr
