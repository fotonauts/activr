require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Timeline do

  it "defines routings" do
    UserNewsFeed.routings.count.should == 2

    UserNewsFeed.routings[:actor_follower].should_not be_nil
    UserNewsFeed.routings[:actor_follower][:to].should be_a(Proc)

    UserNewsFeed.routings[:album_owner].should_not be_nil
    UserNewsFeed.routings[:album_owner][:to].should be_a(Proc)
  end

  it "defines routes" do
  	UserNewsFeed.routes.count.should == 4

    route = UserNewsFeed.routes[0]
    route.should be_an_instance_of(Activr::Timeline::Route)
    route.activity_class.should == AddPhoto
    route.settings.should == { :with => :actor_follower }

    route = UserNewsFeed.routes[1]
    route.should be_an_instance_of(Activr::Timeline::Route)
    route.activity_class.should == AddPhoto
    route.settings.should == { :with => :album_owner }

    route = UserNewsFeed.routes[2]
    route.should be_an_instance_of(Activr::Timeline::Route)
    route.activity_class.should == AddPhoto
    route.settings.should == { :to => :album_follower }

    route = UserNewsFeed.routes[3]
    route.should be_an_instance_of(Activr::Timeline::Route)
    route.activity_class.should == FollowBuddyActivity
    route.settings.should == { :to => :buddy }
  end

  it "checks for route presence" do
    UserNewsFeed.have_route?(Activr::Timeline::Route.new(FollowBuddyActivity, { :to => :buddy })).should be_true
    UserNewsFeed.have_route?(Activr::Timeline::Route.new(FollowBuddyActivity, { :to => :foobarbaz })).should be_false
  end

end
