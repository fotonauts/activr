class FollowBuddyActivity < Activr::Activity

  entity :actor, :class => User
  entity :buddy, :class => User

  def humanize(options = { })
    Activr.sentence("{{actor}} is now following {{buddy}}", :actor => self.actor.fullname, :buddy => self.buddy.fullname)
  end

end
