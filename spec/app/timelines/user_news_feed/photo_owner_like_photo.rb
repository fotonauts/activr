class UserNewsFeed::PhotoOwnerLikePhoto < Activr::Timeline::Entry

  def humanize
    Activr.sentence("{{{actor}}} liked your photo {{{photo}}}", :actor => self.activity.actor.fullname, :photo => self.activity.photo.title)
  end

end
