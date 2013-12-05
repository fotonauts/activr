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
        "picture_owner_like_picture"     => UserNewsFeed::PictureOwnerLikePicture,
      },
    }
  end

  it "registers activities" do
    Activr.registry.activities.should == {
      "add_picture"     => AddPicture,
      "feature_picture" => FeaturePicture,
      "follow_album"    => FollowAlbum,
      "follow_buddy"    => FollowBuddyActivity,
      "like_picture"    => LikePicture,
    }
  end

  it "registers entities" do
    [ AddPicture, FollowBuddyActivity, LikePicture, FeaturePicture, FollowAlbum ].each do |klass|
      Activr.registry.entities[:actor].should include(klass)
    end

    [ AddPicture, LikePicture, FeaturePicture ].each do |klass|
      Activr.registry.entities[:picture].should include(klass)
    end

    [ AddPicture, FollowAlbum ].each do |klass|
      Activr.registry.entities[:album].should include(klass)
    end

    [ FollowBuddyActivity ].each do |klass|
      Activr.registry.entities[:buddy].should include(klass)
    end
  end

end
