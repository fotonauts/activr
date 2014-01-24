require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Timeline::Entry do

  let(:user)    { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)   { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:picture) { Picture.create(:title => "Me myself and I") }
  let(:album)   { Album.create(:name => "Selfies") }
  let(:owner)   { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }

  let(:timeline)      { UserNewsFeedTimeline.new(buddy) }
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
    tl_entry_hash['rcpt'].should == buddy._id
    tl_entry_hash['routing'].should == routing_kind
    tl_entry_hash['meta'].should == meta
    tl_entry_hash['activity']['_id'].should == activity._id
    tl_entry_hash['activity']['kind'].should == activity.kind
    tl_entry_hash['activity']['actor'].should == user._id
    tl_entry_hash['activity']['buddy'].should == buddy._id
  end

  it "instanciates from a hash" do
    tl_entry = Activr::Timeline::Entry.from_hash(tl_entry_hash, timeline)

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

  it "has a timeline route" do
    route = tl_entry.timeline_route
    route.should_not be_nil
    route.kind.should == 'buddy_follow_buddy'
    route.routing_kind.should == 'buddy'
  end

  it "humanizes thanks to :humanize setting" do
    # @todo FIXME
    picture.owner = owner

    activity = FeaturePictureActivity.new(:actor => user, :picture => picture)
    tl_entry = Activr::Timeline::Entry.new(timeline, 'picture_owner', activity)

    tl_entry.humanize.should == "Your picture Me myself and I has been featured"
  end

  it "humanizes thanks to :humanize method in subclass" do
    # @todo FIXME
    picture.owner = owner

    activity = LikePictureActivity.new(:actor => user, :picture => picture)
    tl_entry = UserNewsFeedTimeline::PictureOwnerLikePicture.new(timeline, 'picture_owner', activity)

    tl_entry.humanize.should == "Jean PALE liked your picture Me myself and I"
  end

  it "humanizes thanks to embedded activity" do
    # @todo FIXME
    user.followers = [ buddy ]

    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    tl_entry = Activr::Timeline::Entry.new(timeline, 'actor_follower', activity)

    tl_entry.humanize.should == "Jean PALE added picture Me myself and I to the album Selfies"
  end

  it "stores in database" do
    tl_entry._id.should be_nil
    tl_entry.should_not be_stored

    tl_entry.store!

    tl_entry._id.should_not be_nil
    tl_entry.should be_stored

    tl_entry[:foo].should == 'bar'

    fetched_tl_entry = Activr.storage.find_timeline_entry(timeline, tl_entry._id)
    fetched_tl_entry.should_not be_nil
    fetched_tl_entry._id.should == tl_entry._id
    fetched_tl_entry[:foo].should == 'bar'
  end

end
