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

    Activr.registry.entity_classes.should == {
      :actor   => User,
      :album   => Album,
      :buddy   => User,
      :picture => Picture,
    }

    Activr.registry.activity_entities.should == {
      AddPicture          => [ :actor, :picture, :album ],
      FeaturePicture      => [ :actor, :picture ],
      FollowAlbum         => [ :actor, :album ],
      FollowBuddyActivity => [ :actor, :buddy ],
      LikePicture         => [ :actor, :picture ],
    }
  end

  it "registers models" do
    [ User, Picture, Album ].each do |klass|
      Activr.registry.models.should include(klass)
    end
  end

  it "computes entities for a model class" do
    Activr.registry.activity_entities_for_model(User).should    == [ :actor, :buddy ]
    Activr.registry.activity_entities_for_model(Album).should   == [ :album ]
    Activr.registry.activity_entities_for_model(Picture).should == [ :picture ]
  end

  it "computes timeline entities for a model class" do
    Activr.registry.timeline_entities_for_model(User).should == {
      UserNewsFeed => [ :actor, :buddy ],
    }

    Activr.registry.timeline_entities_for_model(Album).should == {
      UserNewsFeed => [ :album ],
    }

    Activr.registry.timeline_entities_for_model(Picture).should == {
      UserNewsFeed => [ :picture ],
    }
  end

end
