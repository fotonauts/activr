require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Entity::ModelMixin do

  let(:user)      { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)     { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:picture)   { Picture.create(:title => "Me myself and I") }
  let(:picture2)  { Picture.create(:title => 'Prout le mamouth') }
  let(:picture3)  { Picture.create(:title => 'Hihihihi') }
  let(:album)     { Album.create(:name => "Selfies") }
  let(:follower)  { User.create(:_id => 'anne', :first_name => "Anne", :last_name => "CHTITEGOUTE") }
  let(:follower2) { User.create(:_id => 'edmond', :first_name => "Edmond", :last_name => "KUSSAIDUPOULAI") }

  it "fetchs entity activity feed" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity_1.store!

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    activity_2.store!

    Delorean.jump(30)

    activity_3 = LikePictureActivity.new(:actor => user, :picture => picture)
    activity_3.store!

    # user
    activities = user.activities(10)
    activities.size.should == 3

    activities[0]._id.should == activity_3._id
    activities[1]._id.should == activity_2._id
    activities[2]._id.should == activity_1._id

    # user with :skip
    activities = user.activities(10, :skip => 1)
    activities.size.should == 2
    activities[0]._id.should == activity_2._id
    activities[1]._id.should == activity_1._id

    # album
    activities = album.activities(10)
    activities.size.should == 1

    activities[0]._id.should == activity_1._id

    # picture
    activities = picture.activities(10)
    activities.size.should == 2

    activities[0]._id.should == activity_3._id
    activities[1]._id.should == activity_1._id
  end

  it "counts entity activities" do
    AddPictureActivity.new(:actor => user, :picture => picture, :album => album).store!
    FollowBuddyActivity.new(:actor => user, :buddy => buddy).store!
    LikePictureActivity.new(:actor => user, :picture => picture).store!

    user.activities_count.should == 3
    album.activities_count.should == 1
    picture.activities_count.should == 2
  end

  it "deletes activities when entity model is deleted" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity_1.store!

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    activity_2.store!

    Delorean.jump(30)

    activity_3 = LikePictureActivity.new(:actor => user, :picture => picture)
    activity_3.store!

    # test
    picture.destroy

    # check
    user.activities_count.should == 1

    activities = user.activities(10)
    activities.size.should == 1

    activities[0]._id.should == activity_2._id

    album.activities_count.should == 0
    picture.activities_count.should == 0
  end

  it "deletes timeline entries when entity model is deleted" do
    # @todo FIXME
    user.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album))
    Delorean.jump(30)
    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture2, :album => album))
    Delorean.jump(30)
    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture3, :album => album))

    [ follower, follower2 ].each do |rcpt|
      Activr.timeline(UserNewsFeedTimeline, rcpt).count.should == 3
      Activr.timeline(UserNewsFeedTimeline, rcpt).dump.should == [
        "Jean PALE added picture Hihihihi to the album Selfies",
        "Jean PALE added picture Prout le mamouth to the album Selfies",
        "Jean PALE added picture Me myself and I to the album Selfies",
      ]
    end

    # test
    picture2.destroy

    # check
    [ follower, follower2 ].each do |rcpt|
      Activr.timeline(UserNewsFeedTimeline, rcpt).count.should == 2
      Activr.timeline(UserNewsFeedTimeline, rcpt).dump.should == [
        "Jean PALE added picture Hihihihi to the album Selfies",
        "Jean PALE added picture Me myself and I to the album Selfies",
      ]
    end

    # test
    album.destroy

    # check
    [ follower, follower2 ].each do |rcpt|
      Activr.timeline(UserNewsFeedTimeline, rcpt).count.should == 0
    end
  end

end
