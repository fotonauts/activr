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
  def find(col, selector_hash, limit, skip = 0)
    case @kind
    when :moped
      col.find(selector_hash).skip(skip).limit(limit).sort('at' => -1)
    when :mongo
      # compute options hash
      options = {
        :sort  => [ 'at', ::Mongo::DESCENDING ],
        :limit => limit,
        :skip  => skip,
      }

      options[:batch_size] = 100 if (limit > 100)

      col.find(selector_hash, options)
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

  # fetch activities
  #
  # cf. Activr::Storage.fetch_activities
  def find_activities(limit, options = { })
    selector_hash = { }

    # compute selector
    if options[:before]
      selector_hash['at'] ||= { }
      selector_hash['at']["$lt"] = options[:before]
    end

    if options[:after]
      selector_hash['at'] ||= { }
      selector_hash['at']["$gt"] = options[:after]
    end

    (options[:entities] || { }).each do |name, value|
      selector_hash[name.to_s] = value
    end

    if !options[:classes].blank?
      selector_hash['kind'] = { '$in' => options[:classes].map(&:kind) }
    end

    # query
    self.find(self.activity_collection, selector_hash, limit, options[:skip])
  end

  # insert a timeline entry
  def insert_timeline_entry(timeline_kind, timeline_entry_hash)
    self.insert(self.timeline_collection(timeline_kind), timeline_entry_hash)
  end

  # fetch a timeline entry
  def find_timeline_entry(timeline_kind, tl_entry_id)
    self.find_one(self.timeline_collection(timeline_kind), tl_entry_id)
  end

  # fetch timeline entries
  def find_timeline_entries(timeline_kind, recipient_id, limit, skip = 0)
    # compute selector hash
    selector_hash = {
      'tl_kind' => timeline_kind,
      'rcpt'    => recipient_id,
    }

    self.find(self.timeline_collection(timeline_kind), selector_hash, limit, skip)
  end

end # class Activr::Storage::MongoDriver
