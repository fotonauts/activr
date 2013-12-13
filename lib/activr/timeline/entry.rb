#
# A timeline entry correspond to an activity routed to a timeline
#
# When instanciated, it contains:
#   - The `timeline` it belongs to
#   - A copy of the routed `activity`
#   - The `routing_kind` that indicates how that `activity` has been routed
#   - User-defined `meta` data
#
class Activr::Timeline::Entry

  extend ActiveModel::Callbacks

  # callbacks when timeline entry is stored
  define_model_callbacks :store


  class << self

    # Instanciate a timeline entry from a hash
    #
    # @param hash     [Hash]     Timeline entry hash
    # @param timeline [Timeline] Timeline instance
    # @return [Timeline::Entry] Timeline entry instance
    def from_hash(hash, timeline)
      activity_hash = hash['activity'] || hash[:activity]
      raise "No activity found in timeline entry hash: #{hash.inspect}" if activity_hash.blank?

      activity_kind = activity_hash['kind'] || activity_hash[:kind]
      raise "No activity kind in timeline entry activity: #{activity_hash.inspect}" if activity_kind.blank?

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

  # @return [Object] timeline entry id
  attr_accessor :_id

  # @return [Timeline] timeline that owns that timeline entry
  attr_reader :timeline

  # @return [String] routing kind
  attr_reader :routing_kind

  # @return [Activity] embedded activity
  attr_reader :activity

  # @return [Hash] meta data
  attr_reader :meta


  # @param timeline     [Timeline] Timeline instance
  # @param routing_kind [String]   Routing kind
  # @param activity     [Activity] Activity
  # @param meta         [Hash]     Meta data
  def initialize(timeline, routing_kind, activity, meta = { })
    @timeline     = timeline
    @routing_kind = routing_kind
    @activity     = activity
    @meta         = meta && meta.symbolize_keys
  end

  # Get a meta
  #
  # @example
  #   timeline_entry[:foo]
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
  #   timeline_entry[:foo] = 'bar'
  #
  # @param key   [Symbol] Meta name
  # @param value [Object]  Meta value
  def []=(key, value)
    @meta[key.to_sym] = value
  end

  # Serialize timeline entry to a hash
  #
  # @note All keys are stringified (ie. there is no Symbol)
  #
  # @return [Hash] Timeline entry hash
  def to_hash
    # fields
    result = {
      'rcpt'     => @timeline.recipient_id,
      'routing'  => @routing_kind,
      'activity' => @activity.to_hash,
    }

    result['meta'] = @meta.stringify_keys unless @meta.blank?

    result
  end

  # Get the corresponding timeline route
  #
  # @return [Timeline::Route] The route instance
  def timeline_route
    @timeline_route ||= begin
      result = @timeline.route_for_kind(Activr::Timeline::Route.kind_for_routing_and_activity(@routing_kind, @activity.kind))
      raise "Failed to find a route for #{@routing_kind} / #{@activity.kind}: #{self.inspect}" if result.nil?
      result
    end
  end

  # Humanize that timeline entry
  #
  # @note MAY be overriden by child class for specialized humanization
  #
  # @param options (see Activity#humanize)
  # @option options (see Activity#humanize)
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

  # Is it already stored
  #
  # @return [true, false]
  def stored?
    !@_id.nil?
  end

  # Store in database
  #
  # @note SIDE EFFECT: The `_id` field is set
  def store!
    run_callbacks(:store) do
      # store
      @_id = Activr.storage.insert_timeline_entry(self)
    end
  end

end # class Activr::Timeline::Entry
