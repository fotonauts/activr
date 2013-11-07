require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Activity do

  let(:user)  { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:photo) { Picture.create(:title => "Me myself and I") }
  let(:album) { Album.create(:name => "Selfies") }
  let(:buddy) { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }

  it "have allowed entities" do
    AddPhoto.allowed_entities.should == {
      :actor => { :class => User },
      :photo => { :class => Picture },
      :album => { :class => Album },
    }

    FollowBuddyActivity.allowed_entities.should == {
      :actor => { :class => User },
      :buddy => { :class => User },
    }
  end

  it "instanciates with entity models" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    activity.actor_entity.should_not be_nil
    activity.actor.should == user
    activity.actor_id.should == user._id

    activity.photo_entity.should_not be_nil
    activity.photo.should == photo
    activity.photo_id.should == photo._id

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
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    activity.humanize.should == "Jean PALE added photo Me myself and I to the Selfies album"
  end

  it "humanizes thanks to :humanize method in subclass" do
    activity = FollowBuddyActivity.new(:actor => user._id, :buddy => buddy._id)
    activity.humanize.should == "Jean PALE is now following Justine CHTITEGOUTE"
  end

  it "instanciates with meta" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album, :foo => 'bar')
    activity[:foo].should == 'bar'
  end

  it "sets a default :at field on instanciation" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album, :foo => 'bar')
    activity.at.should_not be_nil
  end

  it "sets entities" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    activity.humanize.should == "Jean PALE added photo Me myself and I to the Selfies album"

    activity.actor = buddy
    activity.humanize.should == "Justine CHTITEGOUTE added photo Me myself and I to the Selfies album"

    activity.actor_entity.should_not be_nil
    activity.actor.should == buddy
    activity.actor_id.should == buddy._id
  end

  it "gets and sets meta" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album, :foo => 'bar')
    activity[:foo].should == 'bar'

    activity[:foo] = 'meuh'
    activity[:foo].should == 'meuh'

    activity[:bar] = 'baz'
    activity[:bar].should == 'baz'

    hsh = activity.to_hash
    hsh['foo'].should == 'meuh'
    hsh['bar'].should == 'baz'
  end

  it "checks for validity" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    lambda { activity.check! }.should_not raise_error
  end

  it "raises if a mandatory entity is missing" do
    activity = AddPhoto.new(:actor => user, :photo => photo)
    lambda { activity.check! }.should raise_error(Activr::Activity::MissingEntityError)
  end

  it "does not raise if trying to access an entity defined for another activity" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    lambda { activity.buddy_entity }.should_not raise_error
    activity.buddy_entity.should be_nil

    lambda { activity.buddy }.should_not raise_error
    activity.buddy.should be_nil

    lambda { activity.buddy_id }.should_not raise_error
    activity.buddy_id.should be_nil
  end

  it "stores in database" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    activity._id.should be_nil

    # test
    activity.store!

    # check
    activity._id.should_not be_nil

    fetched_activity = Activr.storage.fetch_activity(activity._id)
    fetched_activity.should_not be_nil
    fetched_activity.class.should == AddPhoto

    fetched_activity.actor.should == activity.actor
    fetched_activity.photo.should == activity.photo
    fetched_activity.album.should == activity.album
  end

  context "when class have NO suffix" do

    it "have a kind computed from class" do
      AddPhoto.kind.should == 'add_photo'
    end

    it "exports to a hash" do
      activity = AddPhoto.new(:actor => user, :photo => photo, :album => album, :foo => 'bar')
      activity.to_hash.should == {
        'kind'  => 'add_photo',
        'at'    => activity.at,
        'actor' => user._id,
        'photo' => photo._id,
        'album' => album._id,
        'foo'   => 'bar',
      }
    end

    it "instanciates from a hash" do
      now = Time.now.utc

      activity = Activr::Activity.from_hash({
        'kind'  => 'add_photo',
        'at'    => now,
        'actor' => user._id,
        'photo' => photo._id,
        'album' => album._id,
        'foo'   => 'bar',
      })

      activity.class.should == AddPhoto
      activity.at.should == now

      activity.actor.should == user
      activity.photo.should == photo
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

end
