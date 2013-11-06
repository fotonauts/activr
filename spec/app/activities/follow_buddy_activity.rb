class FollowBuddyActivity < Activr::Activity

  entity :actor, :class => User
  entity :buddy, :class => User

  humanize "{{actor.fullname}} is now following {{buddy.fullname}}"

end
