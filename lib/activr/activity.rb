module Activr

  #
  # An activity is an event that is (most of the time) performed by a user in your application.
  #
  # When defining an activity you specify allowed entities and a humanization template.
  #
  # When instanciated, an activity contains:
  #   - Concrete `entities` instances
  #   - A timestamp (the `at` field)
  #   - User-defined `meta` data
  #
  # By default, entities are mandatory and the exception {MissingEntityError} is raised when trying to store an activity
  # with a missing entity.
  #
  # When an activity is stored in database, its `_id` field is filled.
  #
  # Model callbacks:
  #   - `before_store`, `around_store` and `after_store` are called when activity is stored in database
  #   - `before_route`, `around_route` and `after_route` are called when activity is routed by the dispatcher
  #
  # @example
  #   class AddPictureActivity < Activr::Activity
  #
  #     entity :actor, :class => User, :humanize => :fullname
  #     entity :picture, :humanize => :title
  #     entity :album, :humanize => :name
  #
  #     humanize "{{{actor}}} added picture {{{picture}}} to the album {{{album}}}"
  #
  #     before_store :set_bar_meta
  #
  #     def set_bar_meta
  #       self[:bar] = 'baz'
  #       true
  #     end
  #
  #   end
  #
  #   activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album, :foo => 'bar')
  #
  #   activity.humanize
  #   # => John WILLIAMS added picture My Face to the album My Selfies
  #
  #   activity[:foo]
  #   => 'bar'
  #
  #   activity.store!
  #
  #   activity._id
  #   => BSON::ObjectId('529cca3d61796d296e020000')
  #
  #   activity[:bar]
  #   => 'baz'
  #
  class Activity

    extend ActiveModel::Callbacks

    # Callbacks when an activity is stored, and routed to timelines
    define_model_callbacks :store, :route


    # Exception: a mandatory entity is missing
    class MissingEntityError < StandardError; end


    # Allowed entities
    class_attribute :allowed_entities, :instance_writer => false
    self.allowed_entities = { }

    # Humanization template
    class_attribute :humanize_tpl, :instance_writer => false
    self.humanize_tpl = nil


    class << self

      # Get activity class kind
      #
      # @example
      #   AddPictureActivity.kind
      #   => 'add_picture'
      #
      # @note Kind is inferred from class name, unless `#set_kind` method is used to force a custom value
      #
      # @return [String] Activity kind
      def kind
        @kind ||= @forced_kind || Activr::Utils.kind_for_class(self, 'activity')
      end

      # Instanciate an activity from a hash
      #
      # @note Correct activity subclass is resolved thanks to `kind` field
      #
      # @param data_hash [Hash] Activity fields
      # @return [Activity] Subclass instance
      def from_hash(data_hash)
        activity_kind = data_hash['kind'] || data_hash[:kind]
        raise "No kind found in activity hash: #{data_hash.inspect}" unless activity_kind

        klass = Activr.registry.class_for_activity(activity_kind)
        klass.new(data_hash)
      end

      # Unserialize an activity hash
      #
      # That method fixes issues remaining after an activity hash has been unserialized partially:
      #
      #   - the `at` field is converted from String to Time
      #   - the `_id` field is converted from `{ '$oid' => [String] }` format to correct `ObjectId` class (`BSON::ObjectId` or `Moped::BSON::ObjectId`)
      #
      # @param data_hash [Hash] Activity fields
      # @return [Hash] Unserialized activity fields
      def unserialize_hash(data_hash)
        result = { }

        data_hash.each do |key, val|
          result[key] = if Activr.storage.serialized_id?(val)
            Activr.storage.unserialize_id(val)
          elsif (key == 'at') && val.is_a?(String)
            Time.parse(val)
          else
            val
          end
        end

        result
      end


      #
      # Class interface
      #

      # Define an allowed entity for that activity class
      #
      # @example That method creates several instance methods, for example with `entity :album`:
      #
      #   # Get the entity model instance
      #   def album
      #     # ...
      #   end
      #
      #   # Set the entity model instance
      #   def album=(value)
      #     # ...
      #   end
      #
      #   # Get the entity id
      #   def album_id
      #     # ...
      #   end
      #
      #   # Get the Activr::Entity instance
      #   def album_entity
      #     # ...
      #   end
      #
      # @note By convention the entity that correspond to a user performing an action should be named `:actor`
      #
      # @param name    [String,Symbol] Entity name
      # @param options [Hash]          Entity options
      # @option options [Class]       :class    Entity model class
      # @option options [Symbol]      :humanize A method name to call on entity model instance to humanize it
      # @option options [String]      :default  Default humanization value
      # @option options [true, false] :optional Is it an optional entity ?
      def entity(name, options = { })
        name = name.to_sym
        raise "Entity already defined: #{name}" unless self.allowed_entities[name].nil?

        if options[:class].nil?
          options = options.dup
          options[:class] = name.to_s.camelize.constantize
        end

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.allowed_entities = self.allowed_entities.merge(name => options)

        # create entity methods
        class_eval <<-EOS, __FILE__, __LINE__
          # eg: actor
          def #{name}
            @entities[:#{name}] && @entities[:#{name}].model
          end

          # eg: actor = ...
          def #{name}=(value)
            @entities.delete(:#{name})

            if (value != nil)
              @entities[:#{name}] = Activr::Entity.new(:#{name}, value, self.allowed_entities[:#{name}])
            end
          end

          # eg: actor_id
          def #{name}_id
            @entities[:#{name}] && @entities[:#{name}].model_id
          end

          # eg: actor_entity
          def #{name}_entity
            @entities[:#{name}]
          end
        EOS

        if (name == :actor) && options[:class] &&
           (options[:class] < Activr::Entity::ModelMixin) &&
           options[:class].activr_entity_settings[:name].nil?
          # sugar so that we don't have to explicitly call `activr_entity` on model class
          options[:class].activr_entity_settings = options[:class].activr_entity_settings.merge(:name => :actor)
        end

        # register used entity
        Activr.registry.add_entity(name, options, self)
      end

      # Define a humanization template for that activity class
      #
      # @param tpl [String] Mustache template
      def humanize(tpl)
        raise "Humanize already defined: #{self.humanize_tpl}" unless self.humanize_tpl.blank?

        self.humanize_tpl = tpl
      end

      # Set activity kind
      #
      # @note Default kind is inferred from class name
      #
      # @param forced_kind [String] Activity kind
      def set_kind(forced_kind)
        @forced_kind = forced_kind.to_s
      end

    end # class << self

    # @return [Object] activity id
    attr_accessor :_id

    # @return [Time] activity timestamp
    attr_accessor :at

    # @return [Hash{Symbol=>Entity}] activity entities
    attr_reader :entities

    # @return [Hash{Symbol=>Object}] activity meta hash (symbolized)
    attr_reader :meta

    # @param data_hash [Hash] Activity fields
    def initialize(data_hash = { })
      @_id = nil
      @at  = nil

      @entities = { }
      @meta     = { }

      data_hash.each do |data_name, data_value|
        data_name = data_name.to_sym

        if (self.allowed_entities[data_name] != nil)
          # entity
          @entities[data_name] = Activr::Entity.new(data_name, data_value, self.allowed_entities[data_name].merge(:activity => self))
        elsif (data_name == :_id)
          # activity id
          @_id = data_value
        elsif (data_name == :at)
          # timestamp
          raise "Wrong :at class: #{data_value.inspect}" unless data_value.is_a?(Time)
          @at = data_value
        elsif self.respond_to?("#{data_name}=")
          # ivar
          self.send("#{data_name}=", data_value)
        elsif (data_name == :kind)
          # ignore it
        elsif (data_name == :meta)
          # meta
          @meta.merge!(data_value.symbolize_keys)
        else
          # sugar for meta data
          self[data_name] = data_value
        end
      end

      # default timestamp
      @at ||= Time.now.utc
    end

    # Get a meta
    #
    # @example
    #   activity[:foo]
    #   # => 'bar'
    #
    # @param key [Symbol] Meta name
    # @return [Object] Meta value
    def [](key)
      @meta[key.to_sym]
    end

    # Set a meta
    #
    # @example
    #   activity[:foo] = 'bar'
    #
    # @param key   [Symbol] Meta name
    # @param value [Object]  Meta value
    def []=(key, value)
      @meta[key.to_sym] = value
    end

    # Serialize activity to a hash
    #
    # @note All keys are stringified (ie. there is no Symbol)
    #
    # @return [Hash] Activity hash
    def to_hash
      result = { }

      # id
      result['_id'] = @_id if @_id

      # timestamp
      result['at'] = @at

      # kind
      result['kind'] = kind.to_s

      # entities
      @entities.each do |entity_name, entity|
        result[entity_name.to_s] = entity.model_id
      end

      # meta
      result['meta'] = @meta.stringify_keys unless @meta.blank?

      result
    end

    # Activity kind
    #
    # @example
    #   AddPictureActivity.new(...).kind
    #   => 'add_picture'
    #
    # @note Kind is inferred from Class name
    #
    # @return [String] Activity kind
    def kind
      self.class.kind
    end

    # Bindings for humanization sentence
    #
    # For each entity, returned hash contains:
    #   :<entity_name>       => <entity humanization>
    #   :<entity_name>_model => <entity model instance>
    #
    # All `meta` are merged in returned hash too.
    #
    # @param options [Hash] Humanization options
    # @return [Hash] Humanization bindings
    def humanization_bindings(options = { })
      result = { }

      @entities.each do |entity_name, entity|
        result[entity_name] = entity.humanize(options)
        result["#{entity_name}_model".to_sym] = entity.model
      end

      result.merge(@meta)
    end

    # Humanize that activity
    #
    # @param options [Hash] Options hash
    # @option options [true, false] :html Output HTML (default: `false`)
    # @return [String] Humanized activity
    def humanize(options = { })
      raise "No humanize_tpl defined" if self.humanize_tpl.blank?

      Activr.sentence(self.humanize_tpl, self.humanization_bindings(options))
    end

    # Check if activity is valid
    #
    # @raise [MissingEntityError] if a mandatory entity is missing
    # @api private
    def check!
      # check mandatory entities
      self.allowed_entities.each do |entity_name, entity_options|
        if !entity_options[:optional] && @entities[entity_name].blank?
          raise Activr::Activity::MissingEntityError, "Missing '#{entity_name}' entity in this '#{self.kind}' activity: #{self.inspect}"
        end
      end
    end

    # Check if activity is stored in database
    #
    # @return [true, false]
    def stored?
      !@_id.nil?
    end

    # Store activity in database
    #
    # @raise [MissingEntityError] if a mandatory entity is missing
    #
    # @note SIDE EFFECT: The `_id` field is set
    def store!
      run_callbacks(:store) do
        # check validity
        self.check!

        # store
        @_id = Activr.storage.insert_activity(self)
      end
    end

    # Sugar so that we can try to fetch an entity defined for another activity (yes, I hate myself for that...)
    #
    # @api private
    def method_missing(sym, *args, &blk)
      # match: actor_entity | actor_id | actor
      match_data = sym.to_s.match(/(.+)_(entity|id)$/)
      entity_name = match_data ? match_data[1].to_sym : sym

      if Activr.registry.entities_names.include?(entity_name)
        # ok, don't worry...
        # define an instance method so that future calls on that method do not rely on method_missing
        self.instance_eval <<-RUBY
          def #{sym}(*args, &blk)
            nil
          end
        RUBY

        self.__send__(sym, *args, &blk)
      else
        # super Michel !
        super
      end
    end

  end # class Activity

end # module Activr
