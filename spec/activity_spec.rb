require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Activity do

  let(:user)  { User.create(:_id => 'user_a', :first_name => "Jean", :last_name => "PALE") }
  let(:photo) { Picture.create(:_id => 'picture_x', :title => "Me myself and I") }
  let(:album) { Album.create(:_id => 'album_1', :name => "Selfies") }
  let(:buddy) { User.create(:_id => 'user_b', :first_name => "Justine", :last_name => "CHTITEGOUTE") }

  it "have allowed entities and meta" do
    AddPhoto.allowed_entities.should == {
      :actor => { :class => User },
      :photo => { :class => Picture },
      :album => { :class => Album },
    }

    AddPhoto.allowed_meta.should == {
      :foo => { },
    }
  end

  it "instanciates with entity models" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    activity.actor.model.should == user
    activity.photo.model.should == photo
    activity.album.model.should == album
  end

  it "instanciates with entities ids" do
    activity = AddPhoto.new(:actor => user._id, :photo => photo._id, :album => album._id)

    activity.actor.model.should == user
    activity.photo.model.should == photo
    activity.album.model.should == album
  end

  it "instanciates with meta" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album, :foo => 'bar')
    activity[:foo].should == 'bar'
  end

  it "sets a default :at field on instanciation" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album, :foo => 'bar')
    activity.at.should_not be_nil
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

  it "humanizes" do
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)

    activity.humanize.should == "Jean PALE added photo Me myself and I to the Selfies album"
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
    lambda { activity.buddy }.should_not raise_error
    activity.buddy.should be_nil
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

      activity.actor.model.should == user
      activity.photo.model.should == photo
      activity.album.model.should == album

      activity[:foo].should == 'bar'
    end

  end

  context "when class have an Activity suffix" do

    it "have a kind computed from class" do
      AddBuddyActivity.kind.should == 'add_buddy'
    end

    it "exports to a hash" do
      activity = AddBuddyActivity.new(:actor => user, :buddy => buddy)
      activity.to_hash.should == {
        'kind'  => 'add_buddy',
        'at'    => activity.at,
        'actor' => user._id,
        'buddy' => buddy._id,
      }
    end

    it "instanciates from a hash" do
      now = Time.now.utc

      activity = Activr::Activity.from_hash({
        'kind'  => 'add_buddy',
        'at'    => now,
        'actor' => user._id,
        'buddy' => buddy._id,
      })

      activity.class.should == AddBuddyActivity
    end

  end

end
