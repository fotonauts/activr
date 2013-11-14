require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Storage do

  let(:user)  { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:photo) { Picture.create(:title => "Me myself and I") }
  let(:album) { Album.create(:name => "Selfies") }
  let(:owner) { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }

  after(:each) do
    Activr.registry.clear_hooks!
  end

  it "runs :will_insert_activity hook" do
    Activr.will_insert_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.will_insert_activity do |activity_hash|
      activity_hash['meta'] ||= { }
      activity_hash['meta']['bar'] = 'baz'
    end

    # test
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    activity.store!

    activity_hash = Activr.storage.collection.find_one({ '_id' => activity._id })
    activity_hash['foo'].should == 'bar'
    activity_hash['meta'].should == {
      'bar' => 'baz',
    }

    fetched_activity = Activr.storage.fetch_activity(activity._id)
    fetched_activity[:foo].should == 'bar'
    fetched_activity[:bar].should == 'baz'
  end

  it "runs :did_fetch_activity hook" do
    Activr.did_fetch_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.did_fetch_activity do |activity_hash|
      activity_hash['meta'] ||= { }
      activity_hash['meta']['bar'] = 'baz'
    end

    # test
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    activity.store!

    # check
    activity_hash = Activr.storage.collection.find_one({ '_id' => activity._id })
    activity_hash['foo'].should be_blank
    activity_hash['meta'].should be_blank

    fetched_activity = Activr.storage.fetch_activity(activity._id)
    fetched_activity[:foo].should == 'bar'
    fetched_activity[:bar].should == 'baz'
  end

  it "runs :will_insert_timeline_entry hook" do
    Activr.will_insert_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['foo'] = 'bar'
    end

    Activr.will_insert_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['bar'] = 'baz'
    end

    # test
    timeline = UserNewsFeed.new(owner)
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner_add_photo', activity)
    timeline_entry.store!

    # check
    timeline_entry_hash = Activr.storage.timeline_collection(timeline.kind).find_one({ '_id' => timeline_entry._id })
    timeline_entry_hash['meta'].should == {
      'foo' => 'bar',
      'bar' => 'baz',
    }
  end

  it "runs :did_fetch_timeline_entry hook" do
    Activr.did_fetch_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['foo'] = 'bar'
    end

    Activr.did_fetch_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['bar'] = 'baz'
    end

    # test
    timeline = UserNewsFeed.new(owner)
    activity = AddPhoto.new(:actor => user, :photo => photo, :album => album)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner_add_photo', activity)
    timeline_entry.store!

    # check
    tl_entries = timeline.fetch(10)
    tl_entries.first[:foo].should == 'bar'
    tl_entries.first[:bar].should == 'baz'
  end

end
