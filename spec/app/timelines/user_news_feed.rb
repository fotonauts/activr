# Timeline: User's news feed
class UserNewsFeed < Activr::Timeline

  # timeline entries classes
  autoload :MyCustomRoutingFollowAlbum, 'user_news_feed/my_custom_routing_follow_album'
  autoload :PhotoOwnerLikePhoto,        'user_news_feed/photo_owner_like_photo'

  # set recipient class
  recipient User


  #
  # Pre-defined Routings
  #

  # define a routing with a Proc
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }

  # define a routing with a Block
  routing :photo_follower do |activity|
    activity.photo.followers
  end


  #
  # Routes
  #

  # route to activity's entity
  route FollowBuddyActivity, :to => 'buddy'

  # route to path
  route AddPhoto, :to => 'album.owner', :humanize => "{{actor.fullname}} added a photo to your {{album.name}} album"

  # route without inline `humanize`, so the #humanize method will be called on default timeline entry class UserNewsFeed::PhotoOwnerLikePhoto
  route LikePhoto, :to => 'photo.owner'

  route FeaturePhoto, :to => 'photo.owner', :humanize => "Your photo {{photo.title}} has been featured"

  # define a custom routing kind (ie. 'my_custom_routing' instead of 'album_owner')
  route FollowAlbum, :to => 'album.owner', :kind => :my_custom_routing

  # route using pre-defined routing
  route AddPhoto, :using => :actor_follower
  route AddPhoto, :using => :photo_follower

  # route using the timeline's class method call: UserNewsFeed.album_follower
  route AddPhoto, :using => :album_follower


  class << self

    # define a routing with a class method
    def album_follower(activity)
      activity.album.followers
    end

  end # class << self

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
