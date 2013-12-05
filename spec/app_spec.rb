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
    Activr.timeline(UserNewsFeed, buddy).dump.should == [
      "Jean PALE is now following Justine CHTITEGOUTE"
    ]
  end

  it "humanizes AddPicture activity" do
    activity = AddPicture.new(:actor => user, :picture => picture, :album => album)
    activity.humanize.should == "Jean PALE added picture Me myself and I to the Selfies album"
  end

  it "humanizes FeaturePicture activity" do
    activity = FeaturePicture.new(:actor => user, :picture => picture)
    activity.humanize.should == "Picture Me myself and I has been featured by Jean PALE"
  end

  it "humanizes FollowAlbum activity" do
    activity = FollowAlbum.new(:actor => user, :album => album)
    activity.humanize.should == "Jean PALE is now following the Selfies album"
  end

  it "humanizes FollowBuddyActivity activity" do
    activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    activity.humanize.should == "Jean PALE is now following Justine CHTITEGOUTE"
  end

  it "humanizes LikePicture activity" do
    activity = LikePicture.new(:actor => user, :picture => picture)
    activity.humanize.should == "Jean PALE liked the Me myself and I picture"
  end

  it "routes AddPicture to actor's followers" do
    # @todo FIXME
    user.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPicture.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeed, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the Selfies album"
    ]

    Activr.timeline(UserNewsFeed, follower2).dump.should == [
      "Jean PALE added picture Me myself and I to the Selfies album"
    ]
  end

  it "routes LikePicture to picture's owner" do
    # @todo FIXME
    picture.owner = owner

    Activr.dispatch!(LikePicture.new(:actor => user, :picture => picture))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Jean PALE liked your picture Me myself and I"
    ]
  end

  it "routes FeaturePicture to picture's owner" do
    # @todo FIXME
    picture.owner = owner

    Activr.dispatch!(FeaturePicture.new(:actor => user, :picture => picture))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Your picture Me myself and I has been featured"
    ]
  end

  it "routes FollowAlbum to album's owner" do
    # @todo FIXME
    album.owner = owner

    Activr.dispatch!(FollowAlbum.new(:actor => user, :album => album))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Jean PALE is now following your Selfies album"
    ]
  end

  it "routes AddPicture to album's owner" do
    # @todo FIXME
    album.owner = owner

    Activr.dispatch!(AddPicture.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Jean PALE added a picture to your Selfies album"
    ]
  end

  it "routes AddPicture to picture's followers" do
    # @todo FIXME
    picture.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPicture.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeed, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the Selfies album"
    ]

    Activr.timeline(UserNewsFeed, follower2).dump.should == [
      "Jean PALE added picture Me myself and I to the Selfies album"
    ]
  end

  it "routes AddPicture to albums's followers" do
    # @todo FIXME
    album.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPicture.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeed, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the Selfies album"
    ]

    Activr.timeline(UserNewsFeed, follower2).dump.should == [
      "Jean PALE added picture Me myself and I to the Selfies album"
    ]
  end

end
