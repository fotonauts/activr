require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Dispatcher do

  let(:user)     { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)    { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:picture)  { Picture.create(:title => "Me myself and I") }
  let(:album)    { Album.create(:name => "Selfies") }
  let(:owner)    { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }
  let(:follower) { User.create(:_id => 'anne', :first_name => "Anne", :last_name => "CHTITEGOUTE") }

  it "instanciates" do
    dispatcher = Activr::Dispatcher.new
    dispatcher.should_not be_nil
  end

  it "raises an exception if activity was not previously stored" do
    dispatcher = Activr::Dispatcher.new

    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)

    lambda{ self.dispatcher.route(activity) }.should raise_error
  end

  it "routes to activity entity" do
    dispatcher = Activr::Dispatcher.new

    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    activity.store!

    # test
    recipients = dispatcher.recipients_for_timeline(UserNewsFeedTimeline, activity)

    # check
    recipients[buddy].should == UserNewsFeedTimeline.route_for_kind('buddy_follow_buddy')
  end

  it "routes to activity path" do
    dispatcher = Activr::Dispatcher.new

    album.owner = owner

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    # test
    recipients = dispatcher.recipients_for_timeline(UserNewsFeedTimeline, activity)

    # check
    recipients[owner].should == UserNewsFeedTimeline.route_for_kind('album_owner_add_picture')
  end

  it "routes with a custom routing kind" do
    dispatcher = Activr::Dispatcher.new

    album.owner = owner

    activity = FollowAlbumActivity.new(:actor => user, :album => album)
    activity.store!

    # test
    recipients = dispatcher.recipients_for_timeline(UserNewsFeedTimeline, activity)

    # check
    recipients[owner].should == UserNewsFeedTimeline.route_for_kind('my_custom_routing_follow_album')
  end

  it "routes with predefined routing" do
    dispatcher = Activr::Dispatcher.new

    user.followers = [ buddy ]

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    # test
    recipients = dispatcher.recipients_for_timeline(UserNewsFeedTimeline, activity)

    # check
    recipients[buddy].should == UserNewsFeedTimeline.route_for_kind('actor_follower_add_picture')
  end

  it "routes with timeline class method" do
    dispatcher = Activr::Dispatcher.new

    album.followers = [ follower ]

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    # test
    recipients = dispatcher.recipients_for_timeline(UserNewsFeedTimeline, activity)

    # check
    recipients[follower].should == UserNewsFeedTimeline.route_for_kind('album_follower_add_picture')
  end

end
