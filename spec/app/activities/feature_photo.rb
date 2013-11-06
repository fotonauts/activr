class FeaturePhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture

  humanize "Photo {{photo.title}} has been featured by {{actor.fullname}}"

end
