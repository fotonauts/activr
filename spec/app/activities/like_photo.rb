class LikePhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture

  humanize "{{actor.fullname}} liked the {{photo.title}} photo"

  before_store :check_bar_meta
  before_store :set_foo_meta

  before_route :check_baz_meta
  before_route :set_tag_meta

  # callback: before_store
  def check_bar_meta
    self[:bar] != 'baz'
  end

  # callback: before_store
  def set_foo_meta
    self[:foo] = 'bar'
    true
  end

  # callback: before_route
  def check_baz_meta
    self[:baz] != 'belongtous'
  end

  # callback: before_route
  def set_tag_meta
    self[:tag] = 'eul'
    true
  end

end
