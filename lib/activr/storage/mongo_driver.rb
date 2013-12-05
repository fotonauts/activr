require 'uri'

begin
  require 'moped'
rescue LoadError
  begin
    require 'mongo'
  rescue LoadError
    raise "[activr] Can't find any suitable mongodb driver: please install 'mongo' or 'moped' gem"
  end
end

# Mongodb generic driver
class Activr::Storage::MongoDriver

  # init
  def initialize
    # check settings
    [ :uri, :collection ].each do |setting|
      raise "Missing setting #{setting} in config: #{self.config.inspect}" if self.config[setting].blank?
    end

    @collections = { }

    @kind = if defined?(::Moped)
      # moped driver
      :moped
    elsif defined?(::Mongo::MongoClient)
      # mongo ruby driver < 2.0.0
      :mongo
    elsif defined?(::Mongo::Client)
      raise "Sorry, mongo gem >= 2.0 is not supported yet"
    else
      raise "Can't find any suitable mongodb driver: please install 'mongo' or 'moped' gem"
    end

    Activr.logger.info("Using mongodb driver: #{@kind}")

    if @kind == :mongo
      uri = URI.parse(self.config[:uri])

      @db_name = uri.path[1..-1]
      raise "Missing database name in setting uri: #{config[:uri]}" if @db_name.blank?
    end
  end

  def serialized_id?(doc_id)
    doc_id.is_a?(Hash) && !doc_id['$oid'].blank?
  end

  def unserialize_id(doc_id)
    # get string representation
    doc_id = self.serialized_id?(doc_id) ? doc_id['$oid'] : doc_id

    if (@kind == :moped) && Moped::VERSION.start_with?("1.")
      # Moped < 2.0.0 uses a custom BSON implementation
      if doc_id.is_a?(::Moped::BSON::ObjectId)
        doc_id
      else
        ::Moped::BSON::ObjectId(doc_id)
      end
    else
      if doc_id.is_a?(::BSON::ObjectId)
        doc_id
      else
        ::BSON::ObjectId.from_string(doc_id)
      end
    end
  end

  # sugar
  def config
    Activr.config.mongodb
  end

  # mongodb connection/session
  def conn
    @conn ||= begin
      case @kind
      when :moped
        ::Moped::Session.connect(self.config[:uri])
      when :mongo
        ::Mongo::MongoClient.from_uri(self.config[:uri])
      end
    end
  end

  # mongodb collection
  def collection(col_name)
    @collections[col_name] ||= begin
      case @kind
      when :moped
        self.conn[col_name]
      when :mongo
        self.conn.db(@db_name).collection(col_name)
      end
    end
  end

  # insert a document in given collection
  #
  # @return Document _id
  def insert(col, doc)
    case @kind
    when :moped
      doc_id = doc[:_id] || doc['_id']
      if doc_id.nil?
        doc_id = if Moped::VERSION.start_with?("2.")
          # Moped >= 2.0.0 uses bson gem
          ::BSON::ObjectId.new
        else
          # Moped < 2.0.0 uses a custom BSON implementation
          ::Moped::BSON::ObjectId.new
        end

        doc['_id'] = doc_id
      end

      col.insert(doc)

      doc_id
    when :mongo
      col.insert(doc)
    end
  end

  # find a document by id
  def find_one(col, doc_id)
    case @kind
    when :moped
      col.find({ "_id" => doc_id }).one
    when :mongo
      col.find_one({ '_id' => doc_id })
    end
  end

  # find documents from given collection
  #
  # @return An Enumerable
  def find(col, selector_hash, limit, skip, sort_field = nil)
    case @kind
    when :moped
      result = col.find(selector_hash).skip(skip).limit(limit)
      result.sort(sort_field => -1) if sort_field
      result
    when :mongo
      # compute options hash
      options = {
        :limit => limit,
        :skip  => skip,
      }

      options[:sort] = [ sort_field, ::Mongo::DESCENDING ] if sort_field

      options[:batch_size] = 100 if (limit > 100)

      col.find(selector_hash, options)
    end
  end

  # count documents from given collection
  def count(col, selector_hash)
    case @kind
    when :moped, :mongo
      col.find(selector_hash).count()
    end
  end

  def activity_collection
    self.collection(self.config[:collection])
  end

  def timeline_collection(kind)
    self.collection("#{kind}_timelines")
  end


  #
  # Main interface
  #

  # insert an activity in main collection
  def insert_activity(activity_hash)
    self.insert(self.activity_collection, activity_hash)
  end

  # fetch an activity from main collection
  def find_activity(activity_id)
    self.find_one(self.activity_collection, activity_id)
  end

  # helper
  def _activities_selector(options)
    result = { }

    # compute selector
    if options[:before]
      result['at'] ||= { }
      result['at']["$lt"] = options[:before]
    end

    if options[:after]
      result['at'] ||= { }
      result['at']["$gt"] = options[:after]
    end

    (options[:entities] || { }).each do |name, value|
      result[name.to_s] = value
    end

    if !options[:only].blank?
      result['kind'] ||= { }
      result['kind']['$in'] = options[:only].map(&:kind)
    end

    if !options[:except].blank?
      result['kind'] ||= { }
      result['kind']['$nin'] = options[:except].map(&:kind)
    end

    result
  end

  # fetch activities
  #
  # cf. Activr::Storage.fetch_activities
  def find_activities(limit, options = { })
    self.find(self.activity_collection, self._activities_selector(options), limit, options[:skip], 'at')
  end

  # count activities
  #
  # cf. Activr::Storage.activities_count
  def activities_count(options = { })
    self.count(self.activity_collection, self._activities_selector(options))
  end

  # insert a timeline entry
  def insert_timeline_entry(timeline_kind, timeline_entry_hash)
    self.insert(self.timeline_collection(timeline_kind), timeline_entry_hash)
  end

  # fetch a timeline entry
  def find_timeline_entry(timeline_kind, tl_entry_id)
    self.find_one(self.timeline_collection(timeline_kind), tl_entry_id)
  end

  # helper
  def _timeline_selector(timeline_kind, recipient_id)
    {
      'rcpt' => recipient_id,
    }
  end

  # fetch timeline entries
  def find_timeline_entries(timeline_kind, recipient_id, limit, skip = 0)
    self.find(self.timeline_collection(timeline_kind), self._timeline_selector(timeline_kind, recipient_id), limit, skip, 'activity.at')
  end

  # Count number of timeline entries
  #
  # @param timeline_kind [String] Timeline kind
  # @param recipient_id  [String] Recipient id
  def count_timeline_entries(timeline_kind, recipient_id)
    self.count(self.timeline_collection(timeline_kind), self._timeline_selector(timeline_kind, recipient_id))
  end

end # class Activr::Storage::MongoDriver
