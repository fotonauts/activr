class FollowAlbumActivity < Activr::Activity

  entity :actor, :class => User, :humanize => :fullname
  entity :album, :class => Album

  humanize "{{{actor}}} is now following the album {{{album}}}"

end
