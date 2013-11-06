class FollowAlbum < Activr::Activity

  entity :actor, :class => User
  entity :album, :class => Album

  humanize "{{actor.fullname}} is now following the {{album.name}} album"

end
