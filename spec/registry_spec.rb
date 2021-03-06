require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Registry do

  it "registers timelines" do
    Activr.registry.timelines.should == {
      "user_news_feed" => UserNewsFeedTimeline,
    }
  end

  it "computes timeline class from timeline kind" do
    Activr.registry.class_for_timeline('user_news_feed').should == UserNewsFeedTimeline
  end

  it "registers timeline entries" do
    Activr.registry.timeline_entries.should == {
      "user_news_feed" => {
        "my_custom_routing_follow_album" => UserNewsFeedTimeline::MyCustomRoutingFollowAlbum,
        "picture_owner_like_picture"     => UserNewsFeedTimeline::PictureOwnerLikePicture,
      },
    }
  end

  it "computes timeline entry class from a timeline route" do
    Activr.registry.class_for_timeline_entry('user_news_feed', 'my_custom_routing_follow_album').should == UserNewsFeedTimeline::MyCustomRoutingFollowAlbum
    Activr.registry.class_for_timeline_entry('user_news_feed', 'picture_owner_like_picture').should == UserNewsFeedTimeline::PictureOwnerLikePicture
  end

  it "registers activities" do
    Activr.registry.activities.should == {
      "add_picture"       => AddPictureActivity,
      "feature_picture"   => FeaturePictureActivity,
      "follow_album"      => FollowAlbumActivity,
      "follow_buddy"      => FollowBuddyActivity,
      "like_picture"      => LikePictureActivity,
      "my_custom_kind"    => TestCustomKindActivity,
      "test_no_suffix"    => TestNoSuffix,
    }
  end

  it "computes activity class from an activity kind" do
    Activr.registry.class_for_activity('add_picture').should == AddPictureActivity
    Activr.registry.class_for_activity('feature_picture').should == FeaturePictureActivity
    Activr.registry.class_for_activity('follow_album').should == FollowAlbumActivity
    Activr.registry.class_for_activity('follow_buddy').should == FollowBuddyActivity
    Activr.registry.class_for_activity('like_picture').should == LikePictureActivity
    Activr.registry.class_for_activity('my_custom_kind').should == TestCustomKindActivity
    Activr.registry.class_for_activity('test_no_suffix').should == TestNoSuffix
  end

  it "registers entities" do
    [ AddPictureActivity, FollowBuddyActivity, LikePictureActivity, FeaturePictureActivity, FollowAlbumActivity ].each do |klass|
      Activr.registry.entities[:actor].should include(klass)
    end

    [ AddPictureActivity, LikePictureActivity, FeaturePictureActivity ].each do |klass|
      Activr.registry.entities[:picture].should include(klass)
    end

    [ AddPictureActivity, FollowAlbumActivity ].each do |klass|
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
      AddPictureActivity     => [ :actor, :picture, :album ],
      FeaturePictureActivity => [ :actor, :picture ],
      FollowAlbumActivity    => [ :actor, :album ],
      FollowBuddyActivity    => [ :actor, :buddy ],
      LikePictureActivity    => [ :actor, :picture ],
      TestCustomKindActivity => [ :actor, :buddy ],
      TestNoSuffix           => [ :actor, :picture, :album ],
    }
  end

  it "computes regitered entities names" do
    Activr.registry.entities_names.sort.should == [ :actor, :album, :buddy, :picture ]
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
      UserNewsFeedTimeline => [ :actor, :buddy ],
    }

    Activr.registry.timeline_entities_for_model(Album).should == {
      UserNewsFeedTimeline => [ :album ],
    }

    Activr.registry.timeline_entities_for_model(Picture).should == {
      UserNewsFeedTimeline => [ :picture ],
    }
  end

end
