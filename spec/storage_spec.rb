require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Storage do

  let(:user)  { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:photo) { Picture.create(:title => "Me myself and I") }
  let(:album) { Album.create(:name => "Selfies") }

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
    pending("todo")
  end

end
