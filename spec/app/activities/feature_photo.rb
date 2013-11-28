class FeaturePhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture

  humanize "Photo {{photo_model.title}} has been featured by {{actor_model.fullname}}"

end
