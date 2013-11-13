require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Registry do

  after(:each) do
    Activr.registry.clear_hooks!
  end

  it "registers timelines" do
    Activr.registry.timelines.should == {
      "user_news_feed" => UserNewsFeed,
    }
  end

  it "registers timeline entries" do
    Activr.registry.timeline_entries.should == {
      "user_news_feed" => {
        "my_custom_routing_follow_album" => UserNewsFeed::MyCustomRoutingFollowAlbum,
        "photo_owner_like_photo"         => UserNewsFeed::PhotoOwnerLikePhoto,
      },
    }
  end

  it "registers activities" do
    Activr.registry.activities.should == {
      "add_photo"     => AddPhoto,
      "feature_photo" => FeaturePhoto,
      "follow_album"  => FollowAlbum,
      "follow_buddy"  => FollowBuddyActivity,
      "like_photo"    => LikePhoto,
    }
  end

  it "registers entities" do
    [ AddPhoto, FollowBuddyActivity, LikePhoto, FeaturePhoto, FollowAlbum ].each do |klass|
      Activr.registry.entities[:actor].should include(klass)
    end

    [ AddPhoto, LikePhoto, FeaturePhoto ].each do |klass|
      Activr.registry.entities[:photo].should include(klass)
    end

    [ AddPhoto, FollowAlbum ].each do |klass|
      Activr.registry.entities[:album].should include(klass)
    end

    [ FollowBuddyActivity ].each do |klass|
      Activr.registry.entities[:buddy].should include(klass)
    end
  end

  it "registers hooks" do
    Activr.registry.clear_hooks!

    Activr.registry.hooks.should be_blank

    # test
    Activr.will_insert_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.did_fetch_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.did_fetch_activity do |activity_hash|
      activity_hash['bar'] = 'baz'
    end

    # check
    Activr.registry.hooks.should_not be_blank
    Activr.registry.hooks(:will_insert_activity).size.should == 1
    Activr.registry.hooks(:did_fetch_activity).size.should == 2

    Activr.registry.clear_hooks!
    Activr.registry.hooks(:will_insert_activity).should be_blank
    Activr.registry.hooks(:did_fetch_activity).should be_blank
  end

end
