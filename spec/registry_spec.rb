require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Registry do

  it "registers timelines" do
    Activr.registry.timelines.should == {
      "user_news_feed" => UserNewsFeed,
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
    Activr.registry.entities.should == {
      :actor => [ AddPhoto, FollowBuddyActivity, LikePhoto, FeaturePhoto, FollowAlbum ],
      :photo => [ AddPhoto, LikePhoto, FeaturePhoto ],
      :album => [ AddPhoto, FollowAlbum ],
      :buddy => [ FollowBuddyActivity ],
    }
  end

end
