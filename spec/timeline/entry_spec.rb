require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Timeline::Entry do

  let(:user)  { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy) { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:photo) { Picture.create(:title => "Me myself and I") }
  let(:album) { Album.create(:name => "Selfies") }
  let(:owner) { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }

  let(:timeline)      { UserNewsFeed.new(buddy) }
  let(:routing_kind)  { 'buddy' }
  let(:activity)      { FollowBuddyActivity.new(:actor => user, :buddy => buddy) }
  let(:meta)          { { 'foo' => 'bar' } }
  let(:tl_entry)      { Activr::Timeline::Entry.new(timeline, routing_kind, activity, meta) }
  let(:tl_entry_hash) { tl_entry.to_hash }

  it "instanciates" do
    tl_entry.should_not be_nil
    tl_entry.activity.class.should == FollowBuddyActivity
    tl_entry.activity.actor.should == user
    tl_entry.activity.buddy.should == buddy
    tl_entry[:foo].should == 'bar'
  end

  it "exports to a hash" do
    tl_entry_hash = tl_entry.to_hash
    tl_entry_hash['tl_kind'].should == 'user_news_feed'
    tl_entry_hash['rcpt'].should == buddy._id
    tl_entry_hash['routing'].should == routing_kind
    tl_entry_hash['meta'].should == meta
    tl_entry_hash['activity']['_id'].should == activity._id
    tl_entry_hash['activity']['kind'].should == activity.kind
    tl_entry_hash['activity']['actor'].should == user._id
    tl_entry_hash['activity']['buddy'].should == buddy._id
  end

  it "instanciates from a hash with timeline param" do
    tl_entry = Activr::Timeline::Entry.from_hash(tl_entry_hash, timeline)

    tl_entry.should_not be_nil
    tl_entry.activity.class.should == FollowBuddyActivity
    tl_entry.activity.actor.should == user
    tl_entry.activity.buddy.should == buddy
    tl_entry[:foo].should == 'bar'
  end

  it "instanciates from a hash without timeline param" do
    tl_entry = Activr::Timeline::Entry.from_hash(tl_entry_hash)

    tl_entry.should_not be_nil
    tl_entry.activity.class.should == FollowBuddyActivity
    tl_entry.activity.actor.should == user
    tl_entry.activity.buddy.should == buddy
    tl_entry[:foo].should == 'bar'
  end

  it "gets and sets meta" do
    tl_entry[:foo].should == 'bar'

    tl_entry[:foo] = 'meuh'
    tl_entry[:foo].should == 'meuh'

    tl_entry[:bar] = 'baz'
    tl_entry[:bar].should == 'baz'

    hsh = tl_entry.to_hash
    hsh['meta'].should == {
      'foo' => 'meuh',
      'bar' => 'baz',
    }
  end

  it "have timeline route" do
    route = tl_entry.timeline_route
    route.should_not be_nil
    route.kind.should == 'buddy_follow_buddy'
    route.routing_kind.should == :buddy
  end

  it "humanizes thanks to :humanize setting" do
    # @todo FIXME
    photo.owner = owner

    activity = FeaturePhoto.new(:actor => user, :photo => photo)
    tl_entry = Activr::Timeline::Entry.new(timeline, 'photo_owner', activity)

    tl_entry.humanize.should == "Your photo Me myself and I has been featured"
  end

  it "humanizes thanks to :humanize method in subclass" do
    # @todo FIXME
    photo.owner = owner

    activity = LikePhoto.new(:actor => user, :photo => photo)
    tl_entry = UserNewsFeed::PhotoOwnerLikePhoto.new(timeline, 'photo_owner', activity)

    tl_entry.humanize.should == "Jean PALE liked your photo Me myself and I"
  end

  it "humanizes thanks to embedded activity" do
    # @todo FIXME
    user.followers = [ buddy ]

    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    tl_entry = Activr::Timeline::Entry.new(timeline, 'actor_follower', activity)

    tl_entry.humanize.should == "Jean PALE added photo Me myself and I to the Selfies album"
  end

  it "stores in database" do
    tl_entry._id.should be_nil

    tl_entry.store!

    tl_entry._id.should_not be_nil
    tl_entry[:foo].should == 'bar'

    fetched_tl_entry = Activr.storage.fetch_timeline_entry(timeline.kind, tl_entry._id)
    fetched_tl_entry.should_not be_nil
    fetched_tl_entry._id.should == tl_entry._id
    fetched_tl_entry[:foo].should == 'bar'
  end

end