module Activr
  class Entity

    attr_reader :name, :options, :activity
    attr_reader :model_class, :model_id

    #
    # @param name    [String] Entity name
    # @param value   [Object|String] Entity value of entity id
    # @param options [Hash] Options hash:
    #   :class => [String] Entity class
    #   :activity => [Activr::Activity] The 'master' activity
    #
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


    #
    # Private
    #

    # helper
    def _is_valid_id?(value)
      value.is_a?(String) || (defined?(::BSON) && value.is_a?(::BSON::ObjectId))
    end

  end # class Entity
end # module Activr
