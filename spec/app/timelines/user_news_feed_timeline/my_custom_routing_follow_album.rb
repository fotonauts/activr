class UserNewsFeedTimeline::MyCustomRoutingFollowAlbum < Activr::Timeline::Entry

  def humanize(options = { })
    Activr.sentence("{{actor.fullname}} is now following your album {{album.name}}", :actor => self.activity.actor, :album => self.activity.album)
  end

end
