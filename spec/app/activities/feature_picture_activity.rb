class FeaturePictureActivity < Activr::Activity

  entity :actor,   :class => User
  entity :picture, :class => Picture

  humanize "Picture {{picture_model.title}} has been featured by {{actor_model.fullname}}"

end
