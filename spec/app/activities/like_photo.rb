class LikePhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture

  humanize "{{actor.fullname}} liked the {{photo.title}} photo"

  before_store :set_foo_meta

  def set_foo_meta
    return false if (self[:bar] == 'baz')

    self[:foo] = 'bar'

    true
  end

end
