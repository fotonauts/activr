class Activr::Timeline::Entry

  extend ActiveModel::Callbacks

  # callbacks when timeline entry is stored
  define_model_callbacks :store


  class << self

    # instanciate an timeline entry from a hash
    def from_hash(hash, timeline = nil)
      activity_hash = hash['activity'] || hash[:activity]
      raise "No activity found in timeline entry hash: #{hash.inspect}" if activity_hash.blank?

      activity_kind = activity_hash['kind'] || activity_hash[:kind]
      raise "No activity kind in timeline entry activity: #{activity_hash.inspect}" if activity_kind.blank?

      timeline ||= begin
        # @todo Not needed, move that to hook if all timelines kinds are stored in the same collection
        tl_kind = hash['tl_kind'] || hash[:tl_kind]
        raise "No tl_kind found in timeline entry hash: #{hash.inspect}" if tl_kind.blank?

        rcpt = hash['rcpt'] || hash[:rcpt]
        raise "No rcpt found in timeline entry hash: #{hash.inspect}" if rcpt.blank?

        timeline_class = Activr.registry.class_for_timeline(tl_kind)
        timeline_class.new(rcpt)
      end

      routing_kind = hash['routing'] || hash[:routing]
      raise "No routing_kind found in timeline entry hash: #{hash.inspect}" if routing_kind.blank?

      activity   = Activr::Activity.from_hash(activity_hash)
      route_kind = Activr::Timeline::Route.kind_for_routing_and_activity(routing_kind, activity_kind)

      klass = Activr.registry.class_for_timeline_entry(timeline.kind, route_kind)
      result = klass.new(timeline, routing_kind, activity, hash['meta'] || hash[:meta])
      result._id = hash['_id'] || hash[:_id]

      result
    end

  end # class << self


  attr_accessor :_id
  attr_reader :timeline, :routing_kind, :activity, :meta

  # init
  def initialize(timeline, routing_kind, activity, meta = { })
    @timeline     = timeline
    @routing_kind = routing_kind
    @activity     = activity
    @meta         = meta && meta.symbolize_keys
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
    # fields
    result = {
      'tl_kind'  => @timeline.kind, # @todo Not needed, move that to hook if all timelines kinds are stored in the same collection
      'rcpt'     => @timeline.recipient_id,
      'routing'  => @routing_kind,
      'activity' => @activity.to_hash,
    }

    result['meta'] = @meta.stringify_keys unless @meta.blank?

    result
  end

  # get timeline route
  def timeline_route
    @timeline_route ||= begin
      result = @timeline.route_for_kind(Activr::Timeline::Route.kind_for_routing_and_activity(@routing_kind, @activity.kind))
      raise "Failed to find a route for #{@routing_kind} / #{@activity.kind}: #{self.inspect}" if result.nil?
      result
    end
  end

  # humanization
  #
  # MAY be overriden by child class for specialized humanization
  #
  # @param options [Hash] Options hash (cf. Activr::Activity#humanize method)
  # @return [String] Humanized timeline entry
  def humanize(options = { })
    if !self.timeline_route.settings[:humanize].blank?
      # specialized humanization
      Activr.sentence(self.timeline_route.settings[:humanize], @activity.humanization_bindings(options))
    else
      # default humanization
      @activity.humanize(options)
    end
  end

  # check if already stored
  def stored?
    !@_id.nil?
  end

  # Store in database
  #
  # This method can raise an exception if activity is not valid
  #
  # SIDE EFFECT: The `_id` field is set
  def store!
    run_callbacks(:store) do
      # @todo Check validity ?

      # store
      @_id = Activr.storage.insert_timeline_entry(self)
    end
  end

end # class Activr::Timeline::Entry
