class LikePhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture

  humanize "{{actor.fullname}} liked the {{photo.title}} photo"

end
