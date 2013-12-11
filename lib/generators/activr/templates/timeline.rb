# encoding: utf-8

class <%= class_name %>Timeline < Activr::Timeline

  recipient <%= recipient_class %>


  #
  # Routes
  #

  # route FollowBuddyActivity, :to => 'buddy', :humanize => "{{{actor}}} is now following you"


  #
  # Callbacks
  #

  def should_handle_activity?(activity, route)
    # return `false` to skip activity routing
    true
  end

  def should_store_timeline_entry?(timeline_entry)
    # return `false` to cancel timeline entry storing
    true
  end

  def will_store_timeline_entry(timeline_entry)
    # this is your last chance to modify timeline entry before it is stored
  end

  def did_store_timeline_entry(timeline_entry)
    # the timeline entry was stored, you can now do some post-processing
  end

end
