require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Timeline do

  let(:user)  { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy) { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }


  it "have routings" do
    UserNewsFeed.routings.count.should == 2

    UserNewsFeed.routings[:actor_follower].should_not be_nil
    UserNewsFeed.routings[:actor_follower][:to].should be_a(Proc)

    UserNewsFeed.routings[:picture_follower].should_not be_nil
    UserNewsFeed.routings[:picture_follower][:to].should be_a(Proc)
  end

  it "have routes" do
    UserNewsFeed.routes.count.should_not be_blank
  end

  it "checks for route presence" do
    UserNewsFeed.have_route?(Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, { :to => :buddy })).should be_true
    UserNewsFeed.have_route?(Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, { :to => :foobarbaz })).should be_false
  end

  it "defines route to activity path" do
    route = UserNewsFeed.route_for_kind('album_owner_add_picture')
    route.should_not be_nil
    route.kind.should == 'album_owner_add_picture'

    route.routing_kind.should == :album_owner
    route.activity_class.should == AddPicture
    route.settings.should == { :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}" }
  end

  it "defines route with custom route kind" do
    route = UserNewsFeed.route_for_kind('my_custom_routing_follow_album')
    route.should_not be_nil
    route.kind.should == 'my_custom_routing_follow_album'

    route.routing_kind.should == :my_custom_routing
    route.activity_class.should == FollowAlbum
    route.settings.should == { :to => 'album.owner', :kind => :my_custom_routing }
  end

  it "defines route to predefined routing" do
    route = UserNewsFeed.route_for_kind('actor_follower_add_picture')
    route.should_not be_nil
    route.kind.should == 'actor_follower_add_picture'

    route.routing_kind.should == :actor_follower
    route.activity_class.should == AddPicture
    route.settings.should == { :using => :actor_follower }
  end

  it "defines route to method routing" do
    route = UserNewsFeed.route_for_kind('album_follower_add_picture')
    route.should_not be_nil
    route.kind.should == 'album_follower_add_picture'

    route.routing_kind.should == :album_follower
    route.activity_class.should == AddPicture
    route.settings.should == { :using => :album_follower }
  end

  it "handles activity" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)

    # test
    timeline = UserNewsFeed.new(buddy)
    tl_entry = timeline.handle_activity(activity, UserNewsFeed.route_for_kind('buddy_follow_buddy'))

    # check
    tl_entry.should_not be_blank

    ary = timeline.fetch(10)
    ary.size.should == 1

    ary.first.activity.kind.should == 'follow_buddy'
    ary.first.activity.actor.should == user
    ary.first.activity.buddy.should == buddy
  end

  it "does not store timeline entry if should_store_timeline_entry callback returns false" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy, :bar => 'baz')

    # test
    timeline = UserNewsFeed.new(buddy)
    tl_entry = timeline.handle_activity(activity, UserNewsFeed.route_for_kind('buddy_follow_buddy'))

    # check
    tl_entry.should be_nil
    timeline.fetch(10).should be_blank
  end

  it "run will_store_timeline_entry callback before storing a new timeline entry in timeline" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy, :foo => 'bar')

    # test
    timeline = UserNewsFeed.new(buddy)
    tl_entry = timeline.handle_activity(activity, UserNewsFeed.route_for_kind('buddy_follow_buddy'))

    # check
    tl_entry.should_not be_blank
    tl_entry.activity[:foo].should == 'tag'

    ary = timeline.fetch(10)
    ary.size.should == 1

    ary.first.activity[:foo].should == 'tag'
  end

  it "fetches entries from database" do
    # @todo
    pending("todo")
  end

end
