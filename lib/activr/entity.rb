module Activr

  #
  # An Entity represents one of your application model involved in activities
  #
  class Entity

    autoload :ModelMixin, 'activr/entity/model_mixin'

    # @return [Symbol] Entity name
    attr_reader :name

    # @return [Hash] Entity options
    attr_reader :options

    # @return [Activity] Activity owning that entity
    attr_reader :activity

    # @return [Class] Entity model class
    attr_reader :model_class

    # @return [Objecy] Entity model id
    attr_reader :model_id


    # @param name    [String] Entity name
    # @param value   [Object] Model instance or model id
    # @param options [Hash] Options hash
    # @option (see Activity.entity)
    # @option options [Activity] :activity Entity belongs to that activity
    def initialize(name, value, options = { })
      @name = name
      @options = options.dup

      @activity    = @options.delete(:activity)
      @model_class = @options.delete(:class)

      if Activr.storage.valid_id?(value)
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

    # Model instance
    #
    # @return [Object] Instance of `:class` option
    def model
      @model ||= self.model_class.find(self.model_id)
    end

    # Humanize entity
    #
    # @param options [hash] Options
    # @option options [true,false] :html Generate HTML ?
    # @return [String] Humanized sentence
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

  end # class Entity

end # module Activr
