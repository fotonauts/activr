# Timeline: User's news feed
class UserNewsFeed < Activr::Timeline
 
  #
  # Routings
  #
 
  # define a routing with a Proc
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }
 
  # define a routing with a Block
  routing :album_owner do |activity|
    activity.album.owner
  end
 
 
  #
  # Routes
  #
 
  # route using pre-defined routing
  route AddPhoto, :with => :actor_follower
  route AddPhoto, :with => :album_owner
 
  # route using the class method call: UserNewsFeed#actor_follower(activity)
  route AddPhoto, :to => :album_follower
 
  # route to activity's entity
  route FollowBuddyActivity, :to => :buddy
 
 
  class << self
 
    # define a routing with a class method
    def album_follower(activity)
      activity.album.followers
    end
 
  end # class << self

end
