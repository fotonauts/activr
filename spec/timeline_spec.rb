require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Timeline do

  it "have routings" do
    UserNewsFeed.routings.count.should == 2

    UserNewsFeed.routings[:actor_follower].should_not be_nil
    UserNewsFeed.routings[:actor_follower][:to].should be_a(Proc)

    UserNewsFeed.routings[:photo_follower].should_not be_nil
    UserNewsFeed.routings[:photo_follower][:to].should be_a(Proc)
  end

  it "have routes" do
    UserNewsFeed.routes.count.should_not be_blank
  end

  it "checkss for route presence" do
    UserNewsFeed.have_route?(Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, { :to => :buddy })).should be_true
    UserNewsFeed.have_route?(Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, { :to => :foobarbaz })).should be_false
  end

  it "defines route to activity path" do
    route = UserNewsFeed.route_for_kind('album_owner_add_photo')
    route.should_not be_nil
    route.kind.should == 'album_owner_add_photo'

    route.routing_kind.should == :album_owner
    route.activity_class.should == AddPhoto
    route.settings.should == { :to => 'album.owner', :humanize => "{{actor.fullname}} added a photo in your {{album.name}} album" }
  end

  it "defines route with custom route kind" do
    route = UserNewsFeed.route_for_kind('my_custom_route')
    route.should_not be_nil
    route.kind.should == 'my_custom_route'

    route.routing_kind.should == :album_owner
    route.activity_class.should == FollowAlbum
    route.settings.should == { :to => 'album.owner', :kind => 'my_custom_route' }
  end

  it "defines route to pre-defined routing" do
    route = UserNewsFeed.route_for_kind('actor_follower_add_photo')
    route.should_not be_nil
    route.kind.should == 'actor_follower_add_photo'

    route.routing_kind.should == :actor_follower
    route.activity_class.should == AddPhoto
    route.settings.should == { :using => :actor_follower }
  end

  it "defines route to method routing" do
    route = UserNewsFeed.route_for_kind('album_follower_add_photo')
    route.should_not be_nil
    route.kind.should == 'album_follower_add_photo'

    route.routing_kind.should == :album_follower
    route.activity_class.should == AddPhoto
    route.settings.should == { :using => :album_follower }
  end

end
