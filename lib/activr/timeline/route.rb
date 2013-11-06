class Activr::Timeline::Route

  attr_reader :activity_class, :settings

  # init
  def initialize(activity_class, settings)
    @activity_class = activity_class
    @settings       = settings
  end

  # route kind
  def kind
    @kind ||= self.settings[:kind] || "#{self.routing_kind}_#{self.activity_class.kind}"
  end

  # routing kind
  def routing_kind
    @routing_kind ||= begin
      if self.settings[:using] && self.settings[:to]
        raise "Several routing kinds specified for #{self.activity_class}: #{self.settings.inspect}"
      end

      if self.settings[:using].blank? && self.settings[:to].blank?
        raise "Missing routing for #{self.activity_class}: #{self.settings.inspect}"
      end

      result = self.settings[:using]
      if result.blank?
        result = if self.settings[:to].is_a?(Symbol)
          self.settings[:to]
        else
          self.settings[:to].to_s.underscore.gsub('.', '_').to_sym
        end
      end

      result
    end
  end

end # class Activr::Timeline::Route
