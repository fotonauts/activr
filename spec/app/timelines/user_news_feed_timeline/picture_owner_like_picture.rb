class UserNewsFeedTimeline::PictureOwnerLikePicture < Activr::Timeline::Entry

  def humanize
    Activr.sentence("{{{actor}}} liked your picture {{{picture}}}", :actor => self.activity.actor.fullname, :picture => self.activity.picture.title)
  end

end
