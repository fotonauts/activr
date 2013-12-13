require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Storage do

  let(:user)    { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:picture) { Picture.create(:title => "Me myself and I") }
  let(:album)   { Album.create(:name => "Selfies") }
  let(:owner)   { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }

  after(:each) do
    Activr.storage.clear_hooks!
  end

  it "runs :will_insert_activity hook" do
    Activr.storage.will_insert_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.storage.will_insert_activity do |activity_hash|
      activity_hash['meta'] ||= { }
      activity_hash['meta']['bar'] = 'baz'
    end

    # test
    activity = AddPicture.new(:actor => user, :picture => picture, :album => album)
    activity.store!
    activity_hash = Activr.storage.driver.find_one(Activr.storage.driver.activity_collection, activity._id)
    activity_hash.should_not be_nil
    activity_hash['foo'].should == 'bar'
    activity_hash['meta'].should == {
      'bar' => 'baz',
    }

    fetched_activity = Activr.storage.find_activity(activity._id)
    fetched_activity[:foo].should == 'bar'
    fetched_activity[:bar].should == 'baz'
  end

  it "runs :did_find_activity hook" do
    Activr.storage.did_find_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.storage.did_find_activity do |activity_hash|
      activity_hash['meta'] ||= { }
      activity_hash['meta']['bar'] = 'baz'
    end

    # test
    activity = AddPicture.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    # check
    activity_hash = Activr.storage.driver.find_one(Activr.storage.driver.activity_collection, activity._id)
    activity_hash['foo'].should be_blank
    activity_hash['meta'].should be_blank

    fetched_activity = Activr.storage.find_activity(activity._id)
    fetched_activity[:foo].should == 'bar'
    fetched_activity[:bar].should == 'baz'
  end

  it "runs :will_insert_timeline_entry hook" do
    Activr.storage.will_insert_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['foo'] = 'bar'
    end

    Activr.storage.will_insert_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['bar'] = 'baz'
    end

    # test
    timeline = UserNewsFeed.new(owner)
    activity = AddPicture.new(:actor => user, :picture => picture, :album => album)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner_add_picture', activity)
    timeline_entry.store!

    # check
    timeline_entry_hash = Activr.storage.driver.find_one(Activr.storage.driver.timeline_collection(timeline.kind), timeline_entry._id)
    timeline_entry_hash['meta'].should == {
      'foo' => 'bar',
      'bar' => 'baz',
    }
  end

  it "runs :did_find_timeline_entry hook" do
    Activr.storage.did_find_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['foo'] = 'bar'
    end

    Activr.storage.did_find_timeline_entry do |timeline_entry_hash|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['bar'] = 'baz'
    end

    # test
    timeline = UserNewsFeed.new(owner)
    activity = AddPicture.new(:actor => user, :picture => picture, :album => album)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner_add_picture', activity)
    timeline_entry.store!

    # check
    fetched_tl_entry = Activr.storage.find_timeline_entry(timeline, timeline_entry._id)
    fetched_tl_entry._id.should == timeline_entry._id
    fetched_tl_entry[:foo].should == 'bar'
    fetched_tl_entry[:bar].should == 'baz'

    tl_entries = timeline.find(10)
    tl_entries.first[:foo].should == 'bar'
    tl_entries.first[:bar].should == 'baz'
  end

end
