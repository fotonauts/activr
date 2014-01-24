require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Timeline do

  let(:user)     { User.create(:_id => 'jpale',   :first_name => "Jean",    :last_name => "PALE") }
  let(:buddy)    { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:follower) { User.create(:_id => 'anne',    :first_name => "Anne",    :last_name => "CHTITEGOUTE") }
  let(:picture)  { Picture.create(:title => "Me myself and I") }
  let(:album)    { Album.create(:name => "Selfies") }
  let(:owner)    { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }


  #
  # Class interface
  #

  it "has a recipient class" do
    UserNewsFeedTimeline.recipient_class.should == User
  end

  it "has routings" do
    UserNewsFeedTimeline.routings.count.should == 2

    UserNewsFeedTimeline.routings['actor_follower'].should_not be_nil
    UserNewsFeedTimeline.routings['actor_follower'][:to].should be_a(Proc)

    UserNewsFeedTimeline.routings['picture_follower'].should_not be_nil
    UserNewsFeedTimeline.routings['picture_follower'][:to].should be_a(Proc)
  end

  it "has routes" do
    UserNewsFeedTimeline.routes.count.should_not be_blank
  end

  it "has a default kind computed from class name" do
    UserNewsFeedTimeline.kind.should == 'user_news_feed'
  end

  it "finds a route by its kind" do
    route = UserNewsFeedTimeline.route_for_kind('album_owner_add_picture')
    route.should_not be_nil
  end

  it "finds a route by its routing kind and activity class" do
    route = UserNewsFeedTimeline.route_for_routing_and_activity('album_owner', AddPictureActivity)
    route.should_not be_nil
    route.kind.should == 'album_owner_add_picture'
  end

  it "finds all routes for an activity class" do
    routes = UserNewsFeedTimeline.routes_for_activity(AddPictureActivity)
    routes.map(&:kind).sort.should == [ "actor_follower_add_picture", "album_follower_add_picture", "album_owner_add_picture", "picture_follower_add_picture" ]
  end

  it "checks for route presence" do
    UserNewsFeedTimeline.have_route?(Activr::Timeline::Route.new(UserNewsFeedTimeline, FollowBuddyActivity, { :to => :buddy })).should be_true
    UserNewsFeedTimeline.have_route?(Activr::Timeline::Route.new(UserNewsFeedTimeline, FollowBuddyActivity, { :to => :foobarbaz })).should be_false
  end

  it "detects a valid recipient" do
    UserNewsFeedTimeline.valid_recipient?(user).should be_true

    str_doc_id = "51a5bb06b7b95d7282000005"
    doc_id = if defined?(::Moped::BSON)
      ::Moped::BSON::ObjectId(str_doc_id)
    elsif defined?(::BSON::ObjectId)
      ::BSON::ObjectId.from_string(str_doc_id)
    else
      str_doc_id
    end

    UserNewsFeedTimeline.valid_recipient?(doc_id).should be_true
  end

  it "detects an invalid recipient" do
    UserNewsFeedTimeline.valid_recipient?(picture).should be_false
    UserNewsFeedTimeline.valid_recipient?(Hash.new).should be_false
  end

  it "computes a recipient id from a recipient class" do
    UserNewsFeedTimeline.recipient_id(user).should == user._id
    UserNewsFeedTimeline.recipient_id(user._id).should == user._id
  end

  it "defines route to activity path" do
    route = UserNewsFeedTimeline.route_for_kind('album_owner_add_picture')
    route.should_not be_nil
    route.kind.should == 'album_owner_add_picture'

    route.routing_kind.should == 'album_owner'
    route.activity_class.should == AddPictureActivity
    route.settings.should == { :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}" }
  end

  it "defines route with custom route kind" do
    route = UserNewsFeedTimeline.route_for_kind('my_custom_routing_follow_album')
    route.should_not be_nil
    route.kind.should == 'my_custom_routing_follow_album'

    route.routing_kind.should == 'my_custom_routing'
    route.activity_class.should == FollowAlbumActivity
    route.settings.should == { :to => 'album.owner', :kind => :my_custom_routing }
  end

  it "defines route to predefined routing" do
    route = UserNewsFeedTimeline.route_for_kind('actor_follower_add_picture')
    route.should_not be_nil
    route.kind.should == 'actor_follower_add_picture'

    route.routing_kind.should == 'actor_follower'
    route.activity_class.should == AddPictureActivity
    route.settings.should == { :using => :actor_follower }
  end

  it "defines route to method routing" do
    route = UserNewsFeedTimeline.route_for_kind('album_follower_add_picture')
    route.should_not be_nil
    route.kind.should == 'album_follower_add_picture'

    route.routing_kind.should == 'album_follower'
    route.activity_class.should == AddPictureActivity
    route.settings.should == { :using => :album_follower }
  end


  #
  # Instance interface
  #

  it "handles activity" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)

    # test
    timeline = UserNewsFeedTimeline.new(buddy)
    tl_entry = timeline.handle_activity(activity, UserNewsFeedTimeline.route_for_kind('buddy_follow_buddy'))

    # check
    tl_entry.should_not be_blank

    ary = timeline.find(10)
    ary.size.should == 1

    ary.first.activity.kind.should == 'follow_buddy'
    ary.first.activity.actor.should == user
    ary.first.activity.buddy.should == buddy
  end

  context "with stored timelines entries" do

    before(:each) do
      @timeline = UserNewsFeedTimeline.new(owner)

      @activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
      @activity_1.store!

      @timeline_entry_1 = Activr::Timeline::Entry.new(@timeline, 'album_owner', @activity_1)
      @timeline_entry_1.store!

      Delorean.jump(30)

      @activity_2 = FollowAlbumActivity.new(:actor => user, :album => album)
      @activity_2.store!

      @timeline_entry_2 = Activr::Timeline::Entry.new(@timeline, 'my_custom_routing', @activity_2)
      @timeline_entry_2.store!
    end

    it "finds timeline entries" do
      @timeline.find(10).map(&:_id).should == [ @timeline_entry_2._id, @timeline_entry_1._id ]
      @timeline.find(1).map(&:_id).should == [ @timeline_entry_2._id ]
    end

    it "counts timelines entries" do
      @timeline.count.should == 2
    end

    it "dumps timeline entries" do
      @timeline.dump.should == [
        "Jean PALE is now following your album Selfies",
        "Jean PALE added a picture to your album Selfies",
      ]

      @timeline.dump(:nb => 1).should == [
        "Jean PALE is now following your album Selfies",
      ]
    end

  end


  #
  # Callbacks
  #

  it "does not handle activity if should_handle_activity callback returns false" do
    user.followers = [ follower ]

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album, :do_not_handle_me => true))

    Activr.timeline(UserNewsFeedTimeline, follower).dump.should be_blank
  end

  it "does not store timeline entry if should_store_timeline_entry callback returns false" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy, :bar => 'baz')

    # test
    timeline = UserNewsFeedTimeline.new(buddy)
    tl_entry = timeline.handle_activity(activity, UserNewsFeedTimeline.route_for_kind('buddy_follow_buddy'))

    # check
    tl_entry.should be_nil
    timeline.find(10).should be_blank
  end

  it "run will_store_timeline_entry callback before storing a new timeline entry in timeline" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy, :foo => 'bar')

    # test
    timeline = UserNewsFeedTimeline.new(buddy)
    tl_entry = timeline.handle_activity(activity, UserNewsFeedTimeline.route_for_kind('buddy_follow_buddy'))

    # check
    tl_entry.should_not be_blank
    tl_entry.activity[:foo].should == 'tag'

    ary = timeline.find(10)
    ary.size.should == 1

    ary.first.activity[:foo].should == 'tag'
  end

end
