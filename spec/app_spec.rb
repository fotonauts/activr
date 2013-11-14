require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Application" do

  let(:user)      { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)     { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:photo)     { Picture.create(:title => "Me myself and I") }
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

  it "routes AddPhoto to actor's followers" do
    # @todo FIXME
    user.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPhoto.new(:actor => user, :photo => photo, :album => album))

    Activr.timeline(UserNewsFeed, follower).dump.should == [
      "Jean PALE added photo Me myself and I to the Selfies album"
    ]

    Activr.timeline(UserNewsFeed, follower2).dump.should == [
      "Jean PALE added photo Me myself and I to the Selfies album"
    ]
  end

  it "routes LikePhoto to photo's owner" do
    # @todo FIXME
    photo.owner = owner

    Activr.dispatch!(LikePhoto.new(:actor => user, :photo => photo))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Jean PALE liked your photo Me myself and I"
    ]
  end

  it "routes FeaturePhoto to photo's owner" do
    # @todo FIXME
    photo.owner = owner

    Activr.dispatch!(FeaturePhoto.new(:actor => user, :photo => photo))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Your photo Me myself and I has been featured"
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

  it "routes AddPhoto to album's owner" do
    # @todo FIXME
    album.owner = owner

    Activr.dispatch!(AddPhoto.new(:actor => user, :photo => photo, :album => album))

    Activr.timeline(UserNewsFeed, owner).dump.should == [
      "Jean PALE added a photo to your Selfies album"
    ]
  end

  it "routes AddPhoto to photo's followers" do
    # @todo FIXME
    photo.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPhoto.new(:actor => user, :photo => photo, :album => album))

    Activr.timeline(UserNewsFeed, follower).dump.should == [
      "Jean PALE added photo Me myself and I to the Selfies album"
    ]

    Activr.timeline(UserNewsFeed, follower2).dump.should == [
      "Jean PALE added photo Me myself and I to the Selfies album"
    ]
  end

  it "routes AddPhoto to albums's followers" do
    # @todo FIXME
    album.followers = [ follower, follower2 ]

    Activr.dispatch!(AddPhoto.new(:actor => user, :photo => photo, :album => album))

    Activr.timeline(UserNewsFeed, follower).dump.should == [
      "Jean PALE added photo Me myself and I to the Selfies album"
    ]

    Activr.timeline(UserNewsFeed, follower2).dump.should == [
      "Jean PALE added photo Me myself and I to the Selfies album"
    ]
  end

end
