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

#
# Generic Mongodb driver
#
# This is main interface with the underlying MongobDB driver, which can be either the official `mongo` driver or `moped`, the `mongoid` driver.
#
class Activr::Storage::MongoDriver

  def initialize
    # check settings
    raise "Missing setting :uri in config: #{self.config.inspect}" if self.config[:uri].blank?

    @collections = { }

    @kind = if defined?(::Moped)
      if defined?(::Moped::BSON)
        # moped < 2.0.0
        :moped_1
      else
        # moped driver
        :moped
      end
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

  # MongoDB config
  #
  # @api private
  #
  # @return [hash] Config
  def config
    Activr.config.mongodb
  end

  # Mongodb connection/session
  #
  # @api private
  #
  # @return [Mongo::MongoClient, Mongo::MongoReplicaSetClient, Moped::Session] Connection handler
  def conn
    @conn ||= begin
      case @kind
      when :moped_1, :moped
        ::Moped::Session.connect(self.config[:uri])
      when :mongo
        ::Mongo::MongoClient.from_uri(self.config[:uri])
      end
    end
  end

  # Mongodb collection
  #
  # @api private
  #
  # @param col_name [String] Collection name
  # @return [Mongo::Collection, Moped::Collection] Collection handler
  def collection(col_name)
    case @kind
    when :moped_1, :moped
      self.conn[col_name]
    when :mongo
      self.conn.db(@db_name).collection(col_name)
    end
  end

  # Insert a document into given collection
  #
  # @api private
  #
  # @param col [Mongo::Collection, Moped::Collection] Collection handler
  # @param doc [Hash] Document hash to insert
  # @return [BSON::ObjectId, Moped::BSON::ObjectId] Inserted document id
  def insert(col, doc)
    case @kind
    when :moped_1, :moped
      doc_id = doc[:_id] || doc['_id']
      if doc_id.nil?
        doc_id = case @kind
        when :moped_1
          # Moped < 2.0.0 uses a custom BSON implementation
          ::Moped::BSON::ObjectId.new
        when :moped
          # Moped >= 2.0.0 uses bson gem
          ::BSON::ObjectId.new
        end

        doc['_id'] = doc_id
      end

      col.insert(doc)

      doc_id
    when :mongo
      col.insert(doc)
    end
  end

  # Find a document by id
  #
  # @api private
  #
  # @param col    [Mongo::Collection, Moped::Collection]  Collection handler
  # @param selector [Hash] Selector hash
  # @return [Hash, OrderedHash, Nil] Document
  def find_one(col, selector)
    case @kind
    when :moped_1, :moped
      col.find(selector).one
    when :mongo
      col.find_one(selector)
    end
  end

  # Find documents in given collection
  #
  # @api private
  #
  # @param col        [Mongo::Collection, Moped::Collection] Collection handler
  # @param selector   [Hash] Selector hash
  # @param limit      [Integer] Maximum number of documents to find
  # @param skip       [Integer] Number of documents to skip
  # @param sort_field [Symbol,String] The field to use to sort documents in descending order
  # @return [Enumerable] An enumerable on found documents
  def find(col, selector, limit, skip, sort_field = nil)
    case @kind
    when :moped_1, :moped
      result = col.find(selector).skip(skip).limit(limit)
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

      col.find(selector, options)
    end
  end

  # Count documents in given collection
  #
  # @api private
  #
  # @param col      [Mongo::Collection, Moped::Collection] Collection handler
  # @param selector [Hash] Selector hash
  # @return [Integer] Number of documents in collections that satisfy given selector
  def count(col, selector)
    case @kind
    when :moped_1, :moped, :mongo
      col.find(selector).count()
    end
  end

  # Delete documents in given collection
  #
  # @api private
  #
  # @param col      [Mongo::Collection, Moped::Collection] Collection handler
  # @param selector [Hash] Selector hash
  def delete(col, selector)
    case @kind
    when :moped_1, :moped
      col.find(selector).remove_all
    when :mongo
      col.remove(selector)
    end
  end

  # Add index to given collection
  #
  # @api private
  #
  # @param col        [Mongo::Collection, Moped::Collection] Collection handler
  # @param index_spec [Array] Array of {String}, {Integer} tuplets with {String} being a field to index and {Integer} the order (`-1` of DESC and `1` for ASC)
  # @param options    [Hash] Options hash
  # @option options [Boolean] :background Background indexing ? (default: `true`)
  # @option options [Boolean] :sparse     Is it a sparse index ? (default: `false`)
  # @return [String] Index created
  def add_index(col, index_spec, options = { })
    options = {
      :background => true,
      :sparse     => false,
    }.merge(options)

    case @kind
    when :moped_1, :moped
      index_spec = index_spec.inject(ActiveSupport::OrderedHash.new) do |memo, field_spec|
        memo[field_spec[0]] = field_spec[1]
        memo
      end

      col.indexes.create(index_spec, options)

      index_spec

    when :mongo
      col.create_index(index_spec, options)
    end
  end

  # Get handler for `activities` collection
  #
  # @api private
  #
  # @return [Mongo::Collection, Moped::Collection] Collection handler
  def activity_collection
    @activity_collection ||= begin
      col_name = self.config[:activities_col]
      if col_name.nil?
        col_name = "activities"
        col_name = "#{self.config[:col_prefix]}_#{col_name}" unless self.config[:col_prefix].blank?
      end

      self.collection(col_name)
    end
  end

  # Get handler for a `<kind>_timelines` collection
  #
  # @api private
  #
  # @param kind [String] Timeline kind
  # @return [Mongo::Collection, Moped::Collection] Collection handler
  def timeline_collection(kind)
    @timeline_collection ||= { }
    @timeline_collection[kind] ||= begin
      col_name = self.config[:timelines_col]
      if col_name.nil?
        col_name = "#{kind}_timelines"
        col_name = "#{self.config[:col_prefix]}_#{col_name}" unless self.config[:col_prefix].blank?
      end

      self.collection(col_name)
    end
  end


  #
  # Main interface with the Storage
  #

  # (see Activr::Storage#valid_id?)
  def valid_id?(doc_id)
    case @kind
    when :moped_1
      doc_id.is_a?(String) || doc_id.is_a?(::Moped::BSON::ObjectId)
    when :mongo, :moped
      doc_id.is_a?(String) || doc_id.is_a?(::BSON::ObjectId)
    end
  end

  # Is it a serialized document id (ie. with format { '$oid' => ... })
  #
  # @return [true,false]
  def serialized_id?(doc_id)
    doc_id.is_a?(Hash) && !doc_id['$oid'].blank?
  end

  # Unserialize a document id
  #
  # @param doc_id [String,Hash] Document id
  # @return [BSON::ObjectId,Moped::BSON::ObjectId] Unserialized document id
  def unserialize_id(doc_id)
    # get string representation
    doc_id = self.serialized_id?(doc_id) ? doc_id['$oid'] : doc_id

    if @kind == :moped_1
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

  # Insert an activity document
  #
  # @api private
  #
  # @param activity_hash [Hash] Activity document to insert
  # @return [BSON::ObjectId, Moped::BSON::ObjectId] Inserted activity id
  def insert_activity(activity_hash)
    self.insert(self.activity_collection, activity_hash)
  end

  # Find an activity document
  #
  # @api private
  #
  # @param activity_id [BSON::ObjectId, Moped::BSON::ObjectId] The activity id
  # @return [Hash, OrderedHash, Nil] Activity document
  def find_activity(activity_id)
    self.find_one(self.activity_collection, { '_id' => activity_id })
  end

  # Compute selector for querying `activities` collection
  #
  # @api private
  #
  # @param options [Hash] Options when querying `activities` collection
  # @return [Hash] The computed selector
  def activities_selector(options)
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

  # (see Storage#find_activities)
  #
  # @api private
  def find_activities(limit, options = { })
    self.find(self.activity_collection, self.activities_selector(options), limit, options[:skip], 'at')
  end

  # (see Storage#count_activities)
  #
  # @api private
  def count_activities(options = { })
    self.count(self.activity_collection, self.activities_selector(options))
  end

  # (see Storage#delete_activities)
  #
  # @api private
  def delete_activities(selector)
    self.delete(self.activity_collection, selector)
  end

  # (see Storage#add_activity_index)
  #
  # @api private
  def add_activity_index(index, options = { })
    index = index.is_a?(Array) ? index : [ index ]
    index_spec = index.map{ |field| [ field, 1 ] }

    self.add_index(self.activity_collection, index_spec, options)
  end

  # Insert a timeline entry document
  #
  # @api private
  #
  # @param timeline_kind       [String] Timeline kind
  # @param timeline_entry_hash [Hash]   Timeline entry document to insert
  def insert_timeline_entry(timeline_kind, timeline_entry_hash)
    self.insert(self.timeline_collection(timeline_kind), timeline_entry_hash)
  end

  # Find a timeline entry document
  #
  # @api private
  #
  # @param timeline_kind [String] Timeline kind
  # @param tl_entry_id   [BSON::ObjectId, Moped::BSON::ObjectId] Timeline entry document id
  # @return [Hash, OrderedHash, Nil] Timeline entry document
  def find_timeline_entry(timeline_kind, tl_entry_id)
    self.find_one(self.timeline_collection(timeline_kind), { '_id' => tl_entry_id })
  end

  # Compute selector for querying a `*_timelines` collection
  #
  # @api private
  #
  # @param timeline_kind [String] Timeline kind
  # @param recipient_id  [String, BSON::ObjectId, Moped::BSON::ObjectId] Recipient id
  # @param options (see Storage#find_timeline)
  # @return [Hash] The computed selector
  def timeline_selector(timeline_kind, recipient_id, options = { })
    result = { 'rcpt' => recipient_id }

    if !options[:only].blank?
      result['$or'] = options[:only].map do |route|
        { 'routing' => route.routing_kind, 'activity.kind' => route.activity_class.kind }
      end
    end

    result
  end

  # Find several timeline entry documents
  #
  # @api private
  #
  # @param timeline_kind [String] Timeline kind
  # @param recipient_id  [String, BSON::ObjectId, Moped::BSON::ObjectId] Recipient id
  # @param limit         [Integer] Max number of entries to find
  # @param options (see Storage#find_timeline)
  # @return [Array<Hash>] An array of timeline entry documents
  def find_timeline_entries(timeline_kind, recipient_id, limit, options = { })
    self.find(self.timeline_collection(timeline_kind), self.timeline_selector(timeline_kind, recipient_id, options), limit, options[:skip], 'activity.at')
  end

  # Count number of timeline entry documents
  #
  # @api private
  #
  # @param timeline_kind [String] Timeline kind
  # @param recipient_id  [String, BSON::ObjectId, Moped::BSON::ObjectId] Recipient id
  # @param options (see Storage#find_timeline)
  # @return [Integer] Number of documents in given timeline
  def count_timeline_entries(timeline_kind, recipient_id, options = { })
    self.count(self.timeline_collection(timeline_kind), self.timeline_selector(timeline_kind, recipient_id, options))
  end

  # (see Storage#delete_timeline_entries)
  #
  # @api private
  def delete_timeline_entries(timeline_kind, selector)
    self.delete(self.timeline_collection(timeline_kind), selector)
  end

  # (see Storage#add_timeline_index)
  #
  # @api private
  def add_timeline_index(timeline_kind, index, options = { })
    index = index.is_a?(Array) ? index : [ index ]
    index_spec = index.map{ |field| [ field, 1 ] }

    self.add_index(self.timeline_collection(timeline_kind), index_spec, options)
  end

end # class Storage::MongoDriver
