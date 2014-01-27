# Timeline: User news feed
class UserNewsFeedTimeline < Activr::Timeline

  # timeline entries classes
  autoload :MyCustomRoutingFollowAlbum, 'user_news_feed_timeline/my_custom_routing_follow_album'
  autoload :PictureOwnerLikePicture,    'user_news_feed_timeline/picture_owner_like_picture'

  # set recipient class
  recipient User

  # trim old timeline entries
  max_length 10


  #
  # Predefined Routings
  #

  # define a routing with a Proc
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }

  # define a routing with a Block
  routing :picture_follower do |activity|
    activity.picture.followers
  end


  #
  # Routes
  #

  # route to activity entity
  route FollowBuddyActivity, :to => 'buddy'

  # route to path
  route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"

  # route without inline `humanize`, so the #humanize method will be called on default timeline entry class UserNewsFeedTimeline::PictureOwnerLikePicture
  route LikePictureActivity, :to => 'picture.owner'

  route FeaturePictureActivity, :to => 'picture.owner', :humanize => "Your picture {{picture_model.title}} has been featured"

  # define a custom routing kind (ie. 'my_custom_routing' instead of 'album_owner')
  route FollowAlbumActivity, :to => 'album.owner', :kind => :my_custom_routing

  # route using predefined routing
  route AddPictureActivity, :using => :actor_follower
  route AddPictureActivity, :using => :picture_follower
  route FollowBuddyActivity, :using => :actor_follower

  # route using the timeline class method call: UserNewsFeedTimeline.album_follower
  route AddPictureActivity, :using => :album_follower


  class << self

    # define a routing with a class method
    def album_follower(activity)
      activity.album.followers
    end

  end # class << self

  # callback to check if given activity should be handled
  def should_handle_activity?(activity, route)
    activity[:do_not_handle_me] != true
  end

  # callback to check if given timeline entry should be stored
  def should_store_timeline_entry?(timeline_entry)
    timeline_entry.activity[:bar] != 'baz'
  end

  # callback before storing timeline entry in database
  def will_store_timeline_entry(timeline_entry)
    if timeline_entry.activity[:foo] == 'bar'
      timeline_entry.activity[:foo] = 'tag'
    end
  end

end
