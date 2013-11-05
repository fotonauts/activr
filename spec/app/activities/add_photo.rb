class AddPhoto < Activr::Activity

  entity :actor, :class => User
  entity :photo, :class => Picture
  entity :album, :class => Album

  meta :foo


  def humanize(options = { })
    bindings = {
      :actor => self.actor.fullname,
      :photo => self.photo.title,
      :album => self.album.name,
    }

    Activr.sentence("{{{actor}}} added photo {{{photo}}} to the {{{album}}} album", bindings)
  end

end
