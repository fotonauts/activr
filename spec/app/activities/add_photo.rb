class AddPhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture
  entity :album, :class => Album

  humanize "{{{actor.fullname}}} added photo {{{photo.title}}} to the {{{album.name}}} album"

end
