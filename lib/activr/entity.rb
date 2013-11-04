module Activr

  class Entity

    attr_reader :name, :activity, :options
    attr_reader :model_class, :model_id

    #
    # @param name     [String] Entity name
    # @param value    [Object|String] Entity value of entity id
    # @param activity [Activr::Activity] The 'master' activity
    # @param options  [Hash] Options hash:
    #   :class => Entity class
    #
    def initialize(name, value, activity, options = { })
      @name = name
      @activity = activity
      @options = options.dup

      @model_class = @options.delete(:class)

      if value.is_a?(String) || (defined?(Moped) && value.is_a?(Moped::BSON::ObjectId))
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

    # Forward method call to model
    #
    # If you don't want to trigger that ugly method_missing mecanism, then use that pattern:
    #     activity.actor.model.fullname
    # instead of that one:
    #     activity.actor.fullname
    def method_missing(sym, *args, &blk)
      if self.model && self.model.respond_to?(sym)
        # define an instance method so that future calls on that method do not rely on method_missing
        self.instance_eval <<-RUBY
          def #{sym}(*args, &blk)
            self.model.__send__(:#{sym}, *args, &blk)
          end
        RUBY

        self.__send__(sym, *args, &blk)
      else
        super
      end
    end

  end # class Entity

end # module Activr
