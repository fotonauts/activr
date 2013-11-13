class UserNewsFeed::MyCustomRoutingFollowAlbum < Activr::Timeline::Entry

  def humanize
    Activr.sentence("{{actor.fullname}} is now following your {{album.name}} album", :actor => self.actor.fullname, :album => self.album.name)
  end

end
