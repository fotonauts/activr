module Activr

  class Activity

    # Exception: a mandatory entity is missing
    class MissingEntityError < StandardError; end


    # allowed entities for that activity class
    class_attribute :allowed_entities
    self.allowed_entities = { }

    # @todo REMOVE THAT IF NOT REALLY NEEDED !
    # allowed metas infos for that activity class
    class_attribute :allowed_meta
    self.allowed_meta = { }


    class << self

      # activity kind
      def kind
        @kind ||= Activr::Utils.kind_for_class(self, 'activity')
      end

      # instanciate an activity from a hash
      def from_hash(hash)
        activity_kind = hash['kind'] || hash[:kind]
        raise "No kind found in activity hash: #{hash.inspect}" unless activity_kind

        klass = Activr::Utils.class_for_kind(activity_kind, 'activity') rescue Activr::Utils.class_for_kind(activity_kind)
        klass.new(hash)
      end


      #
      # Class interface
      #

      # define an entity for that activity
      def entity(name, options = { })
        name = name.to_sym
        raise "Entity already defined: #{name}" unless self.allowed_entities[name].blank?

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.allowed_entities = self.allowed_entities.merge(name => options)

        # create entity getters
        class_eval <<-EOS, __FILE__, __LINE__
          # eg: actor_entity
          def #{name}_entity
            @entities[:#{name}]
          end

          # eg: actor_id
          def #{name}_id
            @entities[:#{name}] && @entities[:#{name}].model_id
          end

          # eg: actor
          def #{name}
            @entities[:#{name}] && @entities[:#{name}].model
          end
        EOS

        # create entity setter
        class_eval <<-EOS, __FILE__, __LINE__
          # eg: actor = ...
          def #{name}=(value)
            @entities.delete(:#{name})

            if (value != nil)
              @entities[:#{name}] = Activr::Entity.new(:#{name}, value, self.allowed_entities[:#{name}])
            end
          end
        EOS

        # register used entity
        Activr.registry.add_entity(name)
      end

      # define a meta for that activity
      def meta(name, options = { })
        raise "Meta already defined: #{name}" unless self.allowed_meta[name].blank?

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.allowed_meta = self.allowed_meta.merge(name => options)
      end

    end # class << self


    attr_accessor :_id, :at
    attr_reader :entities, :meta

    # init
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
          # article _id
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
        else
          # meta data
          self[data_name] = data_value
        end
      end

      # default timestamp
      @at ||= Time.now.utc
    end

    # get a meta
    def [](key)
      @meta[key.to_sym]
    end

    # set a meta
    def []=(key, value)
      @meta[key.to_sym] = value
    end

    # hashify
    def to_hash
      result = { }

      # meta data (with stringified keys)
      result = @meta.inject({ }) do |memo, (meta_name, meta_value)|
        memo[meta_name.to_s] = meta_value
        memo
      end

      # entities
      @entities.each do |entity_name, entity|
        result[entity_name.to_s] = entity.model_id
      end

      # id
      result['_id'] = @_id if @_id

      # timestamp
      result['at'] = @at

      # kind
      result['kind'] = kind.to_s

      result
    end

    # inspect
    def inspect
      self.to_hash.inspect
    end

    # activity kind
    def kind
      self.class.kind
    end

    # raise exception if activity is not valid
    def check!
      # check mandatory entities
      self.allowed_entities.each do |entity_name, entity_options|
        if !entity_options[:optional] && @entities[entity_name].blank?
          raise Activr::Activity::MissingEntityError, "Missing '#{entity_name}' entity in this '#{self.kind}' activity: #{self.inspect}"
        end
      end
    end

    # sugar so that we can try to fetch an entity defined for another activity
    # yes, I hate myself for that...
    def method_missing(sym, *args, &blk)
      # match: actor_entity | actor_id | actor
      match_data = sym.to_s.match(/(.+)_(entity|id)$/)
      entity_name = match_data ? match_data[1].to_sym : sym

      if Activr.registry.entities.include?(entity_name)
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

    # humanize activity
    def humanize(options = { })
      # MUST be implemented by child class
      raise "not implemented"
    end

  end # class Activity

end # module Activr
