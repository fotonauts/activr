require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Activity do

  let(:user)    { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)   { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:picture) { Picture.create(:title => "Me myself and I") }
  let(:album)   { Album.create(:name => "Selfies") }
  let(:owner)   { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }


  it "have allowed entities" do
    AddPictureActivity.allowed_entities.should == {
      :actor   => { :class => User, :humanize => :fullname },
      :picture => { :class => Picture, :humanize => :title },
      :album   => { :class => Album, :humanize => :name },
    }

    FollowBuddyActivity.allowed_entities.should == {
      :actor => { :class => User },
      :buddy => { :class => User },
    }
  end

  it "instanciates with entity models" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    activity.actor_entity.should_not be_nil
    activity.actor.should == user
    activity.actor_id.should == user._id

    activity.picture_entity.should_not be_nil
    activity.picture.should == picture
    activity.picture_id.should == picture._id

    activity.album_entity.should_not be_nil
    activity.album.should == album
    activity.album_id.should == album._id
  end

  it "instanciates with entities ids" do
    activity = FollowBuddyActivity.new(:actor => user._id, :buddy => buddy._id)

    activity.actor_entity.should_not be_nil
    activity.actor.should == user
    activity.actor_id.should == user._id

    activity.buddy_entity.should_not be_nil
    activity.buddy.should == buddy
    activity.buddy_id.should == buddy._id
  end

  it "humanizes thanks to :humanize setting" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.humanize.should == "Jean PALE added picture Me myself and I to the album Selfies"
  end

  it "humanizes thanks to :humanize method in subclass" do
    activity = FollowBuddyActivity.new(:actor => user._id, :buddy => buddy._id)
    activity.humanize.should == "Jean PALE is now following Justine CHTITEGOUTE"
  end

  it "instanciates with meta" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album, :foo => 'bar')
    activity[:foo].should == 'bar'
  end

  it "sets a default :at field on instanciation" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album, :foo => 'bar')
    activity.at.should_not be_nil
  end

  it "sets entities" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.humanize.should == "Jean PALE added picture Me myself and I to the album Selfies"

    activity.actor = buddy
    activity.humanize.should == "Justine CHTITEGOUTE added picture Me myself and I to the album Selfies"

    activity.actor_entity.should_not be_nil
    activity.actor.should == buddy
    activity.actor_id.should == buddy._id
  end

  it "gets and sets meta" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album, :meta => { :foo => 'bar' })
    activity[:foo].should == 'bar'

    activity[:foo] = 'meuh'
    activity[:foo].should == 'meuh'

    activity[:bar] = 'baz'
    activity[:bar].should == 'baz'

    hsh = activity.to_hash
    hsh['meta'].should == {
      'foo' => 'meuh',
      'bar' => 'baz',
    }
  end

  it "initialize with meta sugar" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album, :foo => 'bar')
    activity[:foo].should == 'bar'

    hsh = activity.to_hash
    hsh['meta'].should == {
      'foo' => 'bar',
    }
  end

  it "checks for validity" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    lambda { activity.check! }.should_not raise_error
  end

  it "raises if a mandatory entity is missing" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture)
    lambda { activity.check! }.should raise_error(Activr::Activity::MissingEntityError)
  end

  it "does not raise if trying to access an entity defined for another activity" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    lambda { activity.buddy_entity }.should_not raise_error
    activity.buddy_entity.should be_nil

    lambda { activity.buddy }.should_not raise_error
    activity.buddy.should be_nil

    lambda { activity.buddy_id }.should_not raise_error
    activity.buddy_id.should be_nil
  end

  it "stores in database" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity._id.should be_nil

    # test
    activity.store!

    # check
    activity._id.should_not be_nil

    fetched_activity = Activr.storage.find_activity(activity._id)
    fetched_activity.should_not be_nil
    fetched_activity.class.should == AddPictureActivity

    fetched_activity.actor.should == activity.actor
    fetched_activity.picture.should == activity.picture
    fetched_activity.album.should == activity.album
  end

  it "run before_store callback before storing in database" do
    activity = LikePictureActivity.new(:actor => user, :picture => picture)

    activity.store!

    activity[:foo].should == 'bar'

    fetched_activity = Activr.storage.find_activity(activity._id)
    fetched_activity.should_not be_nil
    fetched_activity[:foo].should == 'bar'
  end

  it "is not stored if before_store callback returns false" do
    activity = LikePictureActivity.new(:actor => user, :picture => picture, :bar => 'baz')

    activity.store!

    activity._id.should be_nil
    fetched_activity = Activr.storage.find_activity(activity._id)
    fetched_activity.should be_nil
  end

  it "run before_route callback before routing to timelines" do
    # @todo FIXME
    picture.owner = owner

    activity = LikePictureActivity.new(:actor => user, :picture => picture)

    Activr.dispatch!(activity)

    activity[:tag].should == 'eul'

    tl_entries = UserNewsFeedTimeline.new(owner).find(10)
    tl_entries.size.should == 1
    tl_entries.first.activity[:tag].should == 'eul'
  end

  it "is not routed to timelines if before_route callback returns false" do
    # @todo FIXME
    picture.owner = owner

    activity = LikePictureActivity.new(:actor => user, :picture => picture, :baz => 'belongtous')

    Activr.dispatch!(activity)

    tl_entries = UserNewsFeedTimeline.new(owner).find(10)
    tl_entries.should be_blank
  end

  context "when class have NO suffix" do

    it "have a kind computed from class" do
      TestNoSuffix.kind.should == 'test_no_suffix'
    end

    it "exports to a hash" do
      activity = TestNoSuffix.new(:actor => user, :picture => picture, :album => album, :foo => 'bar')
      activity.to_hash.should == {
        'kind'    => 'test_no_suffix',
        'at'      => activity.at,
        'actor'   => user._id,
        'picture' => picture._id,
        'album'   => album._id,
        'meta'    => { 'foo'   => 'bar' },
      }
    end

    it "instanciates from a hash" do
      now = Time.now.utc

      activity = Activr::Activity.from_hash({
        'kind'    => 'test_no_suffix',
        'at'      => now,
        'actor'   => user._id,
        'picture' => picture._id,
        'album'   => album._id,
        'foo'     => 'bar',
      })

      activity.class.should == TestNoSuffix
      activity.at.should == now

      activity.actor.should == user
      activity.picture.should == picture
      activity.album.should == album

      activity[:foo].should == 'bar'
    end

  end

  context "when class have an Activity suffix" do

    it "have a kind computed from class" do
      FollowBuddyActivity.kind.should == 'follow_buddy'
    end

    it "exports to a hash" do
      activity = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
      activity.to_hash.should == {
        'kind'  => 'follow_buddy',
        'at'    => activity.at,
        'actor' => user._id,
        'buddy' => buddy._id,
      }
    end

    it "instanciates from a hash" do
      now = Time.now.utc

      activity = Activr::Activity.from_hash({
        'kind'  => 'follow_buddy',
        'at'    => now,
        'actor' => user._id,
        'buddy' => buddy._id,
      })

      activity.class.should == FollowBuddyActivity
    end

  end

  context "when class have a custom kind" do

    it "have a kind computed from class" do
      TestCustomKindActivity.kind.should == 'my_custom_kind'
    end

    it "exports to a hash" do
      activity = TestCustomKindActivity.new(:actor => user, :buddy => buddy)
      activity.to_hash.should == {
        'kind'  => 'my_custom_kind',
        'at'    => activity.at,
        'actor' => user._id,
        'buddy' => buddy._id,
      }
    end

    it "instanciates from a hash" do
      now = Time.now.utc

      activity = Activr::Activity.from_hash({
        'kind'  => 'my_custom_kind',
        'at'    => now,
        'actor' => user._id,
        'buddy' => buddy._id,
      })

      activity.class.should == TestCustomKindActivity
    end

  end

end
