class UserNewsFeed::PhotoOwnerLikePhoto < Activr::Timeline::Entry

  def humanize
    Activr.sentence("{{actor}} liked your photo {{photo}}", :actor => self.actor.fullname, :photo => self.photo.title)
  end

end
