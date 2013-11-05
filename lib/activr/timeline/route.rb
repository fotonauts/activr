class Activr::Timeline::Route

  attr_reader :activity_class, :settings

  # init
  def initialize(activity_class, settings)
    @activity_class = activity_class
    @settings       = settings
  end

  # route kind
  def kind
    @kind ||= self.settings[:kind] || "#{self.routing_kind.to_s.underscore}_#{self.activity_class.kind}"
  end

  # routing kind
  def routing_kind
    @routing_kind ||= begin
      if self.settings[:with] && self.settings[:to]
        raise "Several routing kinds specified: #{self.settings.inspect}"
      end

      result = self.settings[:with] || self.settings[:to]
      raise "Missing routing for #{self.activity_class}: #{self.settings.inspect}" if result.blank?

      result
    end
  end

end # class Activr::Timeline::Route
