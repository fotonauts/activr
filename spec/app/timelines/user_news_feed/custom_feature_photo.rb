class UserNewsFeed::CustomFeaturePhoto < Activr::Timeline::Entry

  def humanize
    Activr.sentence("{{actor}} featured your photo {{photo}}", :actor => self.actor.fullname, :photo => self.photo.title)
  end

end
