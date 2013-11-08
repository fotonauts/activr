class Activr::Timeline::Route

  attr_reader :timeline_class, :activity_class, :settings

  # init
  def initialize(timeline_class, activity_class, settings)
    @timeline_class = timeline_class
    @activity_class = activity_class
    @settings       = settings

    # check timeline settings
    if @timeline_class.recipient_class.nil?
      raise "Missing recipient_class attribute for timeline: #{@timeline_class}"
    end
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

  # resolve recipients for given activity
  def resolve(activity)
    recipients = if self.settings[:using]
      self.resolve_using_method(self.settings[:using], activity)
    elsif self.settings[:to]
      self.resolve_to_path(self.settings[:to], activity)
    else
      raise "Don't know how to resolve recipients: #{self.settings}"
    end

    recipients = [ recipients ] unless recipients.is_a?(Array)
    recipients.compact!

    # check recipients
    bad_recipient = recipients.find{ |recipient| !self.valid_recipient?(recipient) }
    if bad_recipient
      raise "Invalid recipient resolved by route #{self.inspect}: #{bad_recipient.inspect}"
    end

    recipients
  end

  # resolve route using method call
  def resolve_using_method(meth, activity)
    # send method
    self.apply_meth(self.timeline_class, meth, activity)
  end

  # resolve route to path
  def resolve_to_path(path, activity)
    receivers = [ activity ]

    meth_ary = path.to_s.split('.')
    meth_ary.map(&:to_sym).each do |meth|
      receivers = receivers.map do |receiver|
        if !receiver.respond_to?(meth)
          raise "Can't resolve routing path: receiver does not respond to method '#{meth}': #{receiver.inspect}"
        end

        # send method
        self.apply_meth(receiver, meth, activity)
      end.flatten.compact
    end

    receivers
  end


  #
  # Private
  #

  # helper
  def valid_recipient?(recipient)
    recipient.is_a?(self.timeline_class.recipient_class) || recipient.is_a?(String) || (defined?(::BSON) && recipient.is_a?(::BSON::ObjectId))
  end

  # helper
  def apply_meth(receiver, meth, activity)
    case receiver.method(meth).arity
    when 2
      receiver.__send__(meth, activity, self.timeline_class)
    when 1
      receiver.__send__(meth, activity)
    else
      receiver.__send__(meth)
    end
  end

end # class Activr::Timeline::Route
