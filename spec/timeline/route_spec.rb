require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Timeline::Route do

  let(:user)   { User.create(:_id => 'jpale',   :first_name => "Jean",    :last_name => "PALE") }
  let(:buddy)  { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:marcel) { User.create(:_id => 'marcel',  :first_name => "Marcel",  :last_name => "BELIVO") }
  let(:photo)  { Picture.create(:title => "Me myself and I") }
  let(:album)  { Album.create(:name => "Selfies") }

  it "instanciates" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, settings)

    route.activity_class.should == FollowBuddyActivity
    route.settings.should == settings
  end

  it "handle 'direct entity' routing kind" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, settings)
    route.routing_kind.should == :buddy
  end

  it "handle 'predefined' routing kind" do
    settings = { :using => :actor_follower }
    route = Activr::Timeline::Route.new(UserNewsFeed, AddPhoto, settings)
    route.routing_kind.should == :actor_follower
  end

  it "uses provided :kind setting" do
    settings = { :to => :buddy, :kind => 'my_routing' }
    route = Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, settings)
    route.routing_kind.should == :my_routing
    route.kind.should == 'my_routing_follow_buddy'
  end

  it "have a default kind" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(UserNewsFeed, FollowBuddyActivity, settings)
    route.kind.should == 'buddy_follow_buddy'
  end

  # route FollowBuddyActivity, :to => 'buddy'
  it "resolves routing to activity's entity" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)

    # test
    activity.should_receive(:buddy).and_call_original
    receivers = UserNewsFeed.route_for_kind('buddy_follow_buddy').resolve(activity)

    # check
    receivers.should == [ buddy ]
  end

  # route AddPhoto, :to => 'album.owner'
  it "resolves routing to activity's path" do
    # @todo save in model
    album.owner = buddy

    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    # test
    receivers = UserNewsFeed.route_for_kind('album_owner_add_photo').resolve(activity)

    # check
    receivers.should == [ buddy ]
  end

  # route AddPhoto, :using => :actor_follower
  it "resolves pre-defined routing" do
    # @todo save in model
    user.followers = [ buddy, marcel ]

    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    # test
    receivers = UserNewsFeed.route_for_kind('actor_follower_add_photo').resolve(activity)

    # check
    receivers.size.should == 2
    receivers.should include(buddy)
    receivers.should include(marcel)
  end

  # route AddPhoto, :using => :album_follower
  it "resolves routing with timeline's method" do
    # @todo save in model
    album.followers = [ marcel ]

    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    # test
    receivers = UserNewsFeed.route_for_kind('album_follower_add_photo').resolve(activity)

    # check
    receivers.should == [ marcel ]
  end

end
