require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Application" do

  let(:user)      { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)     { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:picture)   { Picture.create(:title => "Me myself and I") }
  let(:album)     { Album.create(:name => "Selfies") }
  let(:owner)     { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }
  let(:follower)  { User.create(:_id => 'anne', :first_name => "Anne", :last_name => "CHTITEGOUTE") }
  let(:follower2) { User.create(:_id => 'edmond', :first_name => "Edmond", :last_name => "KUSSAIDUPOULAI") }

  it "routes FollowBuddyActivity to followed buddy" do
    Activr.dispatch!(FollowBuddyActivity.new(:actor => user, :buddy => buddy))

    # check
    Activr.timeline(UserNewsFeedTimeline, buddy).dump.should == [
      "Jean PALE is now following Justine CHTITEGOUTE"
    ]
  end

  it "humanizes AddPictureActivity activity" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.humanize.should == "Jean PALE added picture Me myself and I to the album Selfies"
  end

  it "humanizes FeaturePictureActivity activity" do
    activity = FeaturePictureActivity.new(:actor => user, :picture => picture)
    activity.humanize.should == "Picture Me myself and I has been featured by Jean PALE"
  end

  it "humanizes FollowAlbumActivity activity" do
    activity = FollowAlbumActivity.new(:actor => user, :album => album)
    activity.humanize.should == "Jean PALE is now following the album Selfies"
  end

  it "humanizes FollowBuddyActivity activity" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    activity.humanize.should == "Jean PALE is now following Justine CHTITEGOUTE"
  end

  it "humanizes LikePictureActivity activity" do
    activity = LikePictureActivity.new(:actor => user, :picture => picture)
    activity.humanize.should == "Jean PALE liked the picture Me myself and I"
  end

  it "routes AddPictureActivity to actor followers" do
    user.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeedTimeline, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]

    Activr.timeline(UserNewsFeedTimeline, follower2).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]
  end

  it "routes LikePictureActivity to picture owner" do
    picture.owner = owner

    Activr.dispatch!(LikePictureActivity.new(:actor => user, :picture => picture))

    Activr.timeline(UserNewsFeedTimeline, owner).dump.should == [
      "Jean PALE liked your picture Me myself and I"
    ]
  end

  it "routes FeaturePictureActivity to picture owner" do
    picture.owner = owner

    Activr.dispatch!(FeaturePictureActivity.new(:actor => user, :picture => picture))

    Activr.timeline(UserNewsFeedTimeline, owner).dump.should == [
      "Your picture Me myself and I has been featured"
    ]
  end

  it "routes FollowAlbumActivity to album owner" do
    album.owner = owner

    Activr.dispatch!(FollowAlbumActivity.new(:actor => user, :album => album))

    Activr.timeline(UserNewsFeedTimeline, owner).dump.should == [
      "Jean PALE is now following your album Selfies"
    ]
  end

  it "routes AddPictureActivity to album owner" do
    album.owner = owner

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeedTimeline, owner).dump.should == [
      "Jean PALE added a picture to your album Selfies"
    ]
  end

  it "routes AddPictureActivity to picture followers" do
    picture.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeedTimeline, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]

    Activr.timeline(UserNewsFeedTimeline, follower2).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]
  end

  it "routes AddPictureActivity to albums followers" do
    album.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeedTimeline, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]

    Activr.timeline(UserNewsFeedTimeline, follower2).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]
  end

end
