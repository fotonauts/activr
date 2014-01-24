require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Timeline::Route do

  let(:user)    { User.create(:_id => 'jpale',   :first_name => "Jean",    :last_name => "PALE") }
  let(:buddy)   { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:marcel)  { User.create(:_id => 'marcel',  :first_name => "Marcel",  :last_name => "BELIVO") }
  let(:picture) { Picture.create(:title => "Me myself and I") }
  let(:album)   { Album.create(:name => "Selfies") }

  it "instanciates" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(UserNewsFeedTimeline, FollowBuddyActivity, settings)

    route.activity_class.should == FollowBuddyActivity
    route.settings.should == settings
  end

  it "handle 'direct entity' routing kind" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(UserNewsFeedTimeline, FollowBuddyActivity, settings)
    route.routing_kind.should == 'buddy'
  end

  it "handle 'predefined' routing kind" do
    settings = { :using => :actor_follower }
    route = Activr::Timeline::Route.new(UserNewsFeedTimeline, AddPictureActivity, settings)
    route.routing_kind.should == 'actor_follower'
  end

  it "uses provided :kind setting" do
    settings = { :to => :buddy, :kind => 'my_routing' }
    route = Activr::Timeline::Route.new(UserNewsFeedTimeline, FollowBuddyActivity, settings)
    route.routing_kind.should == 'my_routing'
    route.kind.should == 'my_routing_follow_buddy'
  end

  it "has a default kind" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(UserNewsFeedTimeline, FollowBuddyActivity, settings)
    route.kind.should == 'buddy_follow_buddy'
  end

  # route FollowBuddyActivity, :to => 'buddy'
  it "resolves routing to activity entity" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)

    # test
    activity.should_receive(:buddy).and_call_original
    receivers = UserNewsFeedTimeline.route_for_kind('buddy_follow_buddy').resolve(activity)

    # check
    receivers.should == [ buddy ]
  end

  # route AddPictureActivity, :to => 'album.owner'
  it "resolves routing to activity path" do
    album.owner = buddy

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    # test
    receivers = UserNewsFeedTimeline.route_for_kind('album_owner_add_picture').resolve(activity)

    # check
    receivers.should == [ buddy ]
  end

  # route AddPictureActivity, :using => :actor_follower
  it "resolves predefined routing" do
    user.followers = [ buddy, marcel ]

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    # test
    receivers = UserNewsFeedTimeline.route_for_kind('actor_follower_add_picture').resolve(activity)

    # check
    receivers.size.should == 2
    receivers.should include(buddy)
    receivers.should include(marcel)
  end

  # route AddPictureActivity, :using => :album_follower
  it "resolves routing with timeline method" do
    album.followers = [ marcel ]

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    # test
    receivers = UserNewsFeedTimeline.route_for_kind('album_follower_add_picture').resolve(activity)

    # check
    receivers.should == [ marcel ]
  end

end
