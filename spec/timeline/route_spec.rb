require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Timeline::Route do

  it "instanciates" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(FollowBuddyActivity, settings)

    route.activity_class.should == FollowBuddyActivity
    route.settings.should == settings
  end

  it "handle 'direct entity' routing kind" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(FollowBuddyActivity, settings)
    route.routing_kind.should == :buddy
  end

  it "handle 'predefined' routing kind" do
    settings = { :with => :actor_follower }
    route = Activr::Timeline::Route.new(AddPhoto, settings)
    route.routing_kind.should == :actor_follower
  end

  it "uses provided :kind setting" do
    settings = { :to => :buddy, :kind => 'my_route' }
    route = Activr::Timeline::Route.new(FollowBuddyActivity, settings)
    route.kind.should == 'my_route'
  end

  it "generates a default kind" do
    settings = { :to => :buddy }
    route = Activr::Timeline::Route.new(FollowBuddyActivity, settings)
    route.kind.should == 'buddy_follow_buddy'
  end

end
