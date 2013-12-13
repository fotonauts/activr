#
# A timeline route describes how an activity is routed to a timeline
#
class Activr::Timeline::Route

  # @return [Class] timeline class
  attr_reader :timeline_class

  # @return [Class] activity class
  attr_reader :activity_class

  # @return [Hash] route settings
  attr_reader :settings


  class << self

    # Get route kind
    #
    # @param routing_kind  [String] Routing kind
    # @param activity_kind [String] Activity kind
    # @return [String] Route kind
    def kind_for_routing_and_activity(routing_kind, activity_kind)
      "#{routing_kind}_#{activity_kind}"
    end

  end # class << self


  # @param timeline_class [Class] Timeline class
  # @param activity_class [Class] Activity class
  # @param settings       [Hash] Route settings
  # @option settings [Symbol] :using Predefined routing kind
  # @option settings [Symbol] :to    Routing path
  # @option settings [Symbol] :kind  Manually specified routing kind
  def initialize(timeline_class, activity_class, settings)
    @timeline_class = timeline_class
    @activity_class = activity_class
    @settings       = settings
  end

  # Get route kind
  #
  # @return [String] Route kind
  def kind
    @kind ||= self.class.kind_for_routing_and_activity(self.routing_kind, self.activity_class.kind)
  end

  # Get routing kind
  #
  # @return [String] Routing kind
  def routing_kind
    @routing_kind ||= (self.settings[:kind] && self.settings[:kind].to_s) || begin
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

      result.to_s
    end
  end

  # Resolve recipients for given activity
  #
  # @param activity [Activity] Activity to resolve
  # @return [Array<Object>] Array of recipients instances and/or ids
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
    bad_recipient = recipients.find{ |recipient| !self.timeline_class.valid_recipient?(recipient) }
    if bad_recipient
      raise "Invalid recipient resolved by route #{self.inspect}: #{bad_recipient.inspect}"
    end

    recipients
  end

  # Resolve route using method call
  #
  # @api private
  #
  # @param meth     [Symbol]   Method to call on timeline class
  # @param activity [Activity] Activity to resolve
  # @return [Array<Object>] Array of recipients instances and/or ids
  def resolve_using_method(meth, activity)
    # send method
    self.apply_meth(self.timeline_class, meth, activity)
  end

  # Resolve route using path
  #
  # @api private
  #
  # @param path     [String]   Path on activity
  # @param activity [Activity] Activity to resolve
  # @return [Array<Object>] Array of recipients instances and/or ids
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

  # Apply a method on receiver, with given activity as parameter if receiver arity permits it
  #
  # @api private
  #
  # @param receiver [Object]   Receiver
  # @param meth     [Symbol]   Method to call
  # @param activity [Activity] Activity to provide in method call
  # @return [Object] Result of method call on receiver
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
