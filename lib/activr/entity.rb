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

      if options[:html] && @options[:htmlize]
        # the model knows how to safely htmlize itself
        result = self.model.__send__(@options[:htmlize])
      else
        if @options[:humanize]
          case self.model.method(@options[:humanize]).arity
          when 1
            result = self.model.__send__(@options[:humanize], options)
          else
            result = self.model.__send__(@options[:humanize])
          end
        end
      end

      if result.blank? && @options[:default]
        result = @options[:default]
      end

      if !result.blank? && options[:html] && !@options[:htmlize] && Activr::RailsCtx.view_context
        # let Rails sanitize and htmlize the entity
        result = Activr::RailsCtx.view_context.sanitize(result)
        result = Activr::RailsCtx.view_context.link_to(result, self.model)
      end

      result ||= ""

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
