require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Registry do

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

end
