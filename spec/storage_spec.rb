require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Storage do

  let(:user)     { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:picture)  { Picture.create(:title => "Me myself and I") }
  let(:album)    { Album.create(:name => "Selfies") }
  let(:owner)    { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }
  let(:buddy)    { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:follower) { User.create(:_id => 'anne',    :first_name => "Anne",    :last_name => "CHTITEGOUTE") }

  after(:each) do
    Activr.storage.clear_hooks!
  end

  it "detects a valid document id" do
    str_doc_id = "51a5bb06b7b95d7282000005"
    Activr.storage.valid_id?(str_doc_id).should be_true

    doc_id = if defined?(::Moped::BSON)
      ::Moped::BSON::ObjectId(str_doc_id)
    elsif defined?(::BSON::ObjectId)
      ::BSON::ObjectId.from_string(str_doc_id)
    else
      str_doc_id
    end

    Activr.storage.valid_id?(doc_id).should be_true
  end

  it "detects an invalid document id" do
    Activr.storage.valid_id?(Hash.new).should be_false
  end

  it "detects a serialized document id" do
    doc_id = { '$oid' => '51a5bb06b7b95d7282000005' }
    Activr.storage.serialized_id?(doc_id).should be_true
  end

  it "detects a not serialized document id" do
    doc_id = '51a5bb06b7b95d7282000005'
    Activr.storage.serialized_id?(doc_id).should be_false
  end

  it "unserialize a document id" do
    hash_doc_id = { '$oid' => '51a5bb06b7b95d7282000005' }
    doc_id = Activr.storage.unserialize_id(hash_doc_id)

    Activr.storage.valid_id?(doc_id).should be_true
  end


  #
  # Activities
  #

  it "inserts an activity" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    doc_id = Activr.storage.insert_activity(activity)

    Activr.storage.valid_id?(doc_id).should be_true
  end

  it "finds an activity by id" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    doc_id = Activr.storage.insert_activity(activity)

    fetched_activity = Activr.storage.find_activity(doc_id)
    fetched_activity.should_not be_nil
    fetched_activity._id.should == doc_id
  end

  context "with stored activities" do

    before(:each) do
      @activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
      @activity_1.store!

      Delorean.jump(30)

      @activity_2 = FollowAlbumActivity.new(:actor => user, :album => album)
      @activity_2.store!
    end

    it "finds activities" do
      Activr.storage.find_activities(10).map(&:_id).should == [ @activity_2._id, @activity_1._id ]
    end

    it "counts activities" do
      Activr.storage.count_activities.should == 2
    end

    it "finds activities filtered with :only option" do
      Activr.storage.find_activities(10, :only => AddPictureActivity).map(&:_id).should  == [ @activity_1._id ]
      Activr.storage.find_activities(10, :only => FollowAlbumActivity).map(&:_id).should == [ @activity_2._id ]
      Activr.storage.find_activities(10, :only => LikePictureActivity).should == [ ]
      Activr.storage.find_activities(10, :only => [ AddPictureActivity, FollowAlbumActivity ]).map(&:_id).should  == [ @activity_2._id, @activity_1._id ]
      Activr.storage.find_activities(10, :only => [ AddPictureActivity, LikePictureActivity ]).map(&:_id).should  == [ @activity_1._id ]
    end

    it "counts activities filtered with :only option" do
      Activr.storage.count_activities(:only => AddPictureActivity).should  == 1
      Activr.storage.count_activities(:only => FollowAlbumActivity).should == 1
      Activr.storage.count_activities(:only => LikePictureActivity).should == 0
      Activr.storage.count_activities(:only => [ AddPictureActivity, FollowAlbumActivity ]).should == 2
      Activr.storage.count_activities(:only => [ AddPictureActivity, LikePictureActivity ]).should == 1
    end

    it "find activities with :entities option" do
      Activr.storage.find_activities(10, :entities => { :actor => user._id }).map(&:_id).should  == [ @activity_2._id, @activity_1._id ]
      Activr.storage.find_activities(10, :entities => { :picture => picture._id }).map(&:_id).should  == [ @activity_1._id ]
      Activr.storage.find_activities(10, :entities => { :album => album._id }).map(&:_id).should  == [ @activity_2._id, @activity_1._id ]
      Activr.storage.find_activities(10, :entities => {:actor => user._id, :album => album._id }).map(&:_id).should  == [ @activity_2._id, @activity_1._id ]
      Activr.storage.find_activities(10, :entities => {:actor => user._id, :picture => picture._id, :album => album._id }).map(&:_id).should == [ @activity_1._id ]
    end

    it "counts activities filtered with :only option" do
      Activr.storage.count_activities(:entities => { :actor => user._id }).should  == 2
      Activr.storage.count_activities(:entities => { :picture => picture._id }).should == 1
      Activr.storage.count_activities(:entities => { :album => album._id }).should == 2
      Activr.storage.count_activities(:entities => {:actor => user._id, :album => album._id }).should == 2
      Activr.storage.count_activities(:entities => {:actor => user._id, :picture => picture._id, :album => album._id }).should == 1
    end

    it "deletes activities referring to an entity model instance" do
      Activr.storage.delete_activities_for_entity_model(picture)

      # check
      Activr.storage.find_activities(10).map(&:_id).should == [ @activity_2._id ]

      Activr.storage.delete_activities_for_entity_model(user)

      # check
      Activr.storage.find_activities(10).map(&:_id).should == [ ]
    end

  end

  it "counts duplicate activities" do
    AddPictureActivity.new(:actor => user, :picture => picture, :album => album).store!

    Delorean.jump(10)

    FollowAlbumActivity.new(:actor => user, :album => album).store!

    Delorean.jump(10)

    AddPictureActivity.new(:actor => user, :picture => picture, :album => album).store!

    Delorean.jump(10)

    AddPictureActivity.new(:actor => user, :picture => picture, :album => album).store!

    Delorean.jump(10)

    # check
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    Activr.storage.count_duplicate_activities(activity, Time.now.utc - 45).should == 3
    Activr.storage.count_duplicate_activities(activity, Time.now.utc - 35).should == 2
    Activr.storage.count_duplicate_activities(activity, Time.now.utc - 15).should == 1
    Activr.storage.count_duplicate_activities(activity, Time.now.utc - 5).should == 0
  end


  #
  # Timelines
  #

  it "inserts a timeline entry" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    timeline = UserNewsFeedTimeline.new(owner)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner', activity)

    doc_id = Activr.storage.insert_timeline_entry(timeline_entry)
    doc_id.should_not be_nil
  end

  it "finds a timeline entry by id" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    timeline = UserNewsFeedTimeline.new(owner)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner', activity)

    doc_id = Activr.storage.insert_timeline_entry(timeline_entry)

    fetched_tl_entry = Activr.storage.find_timeline_entry(timeline, doc_id)
    fetched_tl_entry.should_not be_nil
    fetched_tl_entry._id.should == doc_id
  end

  context "with stored timelines entries" do

    before(:each) do
      @timeline = UserNewsFeedTimeline.new(owner)

      @activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
      @activity_1.store!

      @timeline_entry_1 = Activr::Timeline::Entry.new(@timeline, 'album_owner', @activity_1)
      @timeline_entry_1.store!

      Delorean.jump(30)

      @activity_2 = FollowAlbumActivity.new(:actor => user, :album => album)
      @activity_2.store!

      @timeline_entry_2 = Activr::Timeline::Entry.new(@timeline, 'my_custom_routing', @activity_2)
      @timeline_entry_2.store!
    end

    it "finds timeline entries" do
      Activr.storage.find_timeline(@timeline, 10).map(&:_id).should == [ @timeline_entry_2._id, @timeline_entry_1._id ]
    end

    it "counts timeline entries" do
      Activr.storage.count_timeline(@timeline).should == 2
    end

    it "finds timeline entries filtered with :only option" do
      route = @timeline.route_for_routing_and_activity('my_custom_routing', FollowAlbumActivity)
      route.should_not be_nil
      Activr.storage.find_timeline(@timeline, 10, :only => route).map(&:_id).should == [ @timeline_entry_2._id ]

      route = @timeline.route_for_routing_and_activity('album_owner', AddPictureActivity)
      route.should_not be_nil
      Activr.storage.find_timeline(@timeline, 10, :only => route).map(&:_id).should == [ @timeline_entry_1._id ]

      route = @timeline.route_for_routing_and_activity('picture_owner', LikePictureActivity)
      route.should_not be_nil
      Activr.storage.find_timeline(@timeline, 10, :only => route).should == [ ]
    end

    it "counts timeline entries filtered with :only option" do
      route = @timeline.route_for_routing_and_activity('my_custom_routing', FollowAlbumActivity)
      route.should_not be_nil
      Activr.storage.count_timeline(@timeline, :only => route).should == 1

      route = @timeline.route_for_routing_and_activity('album_owner', AddPictureActivity)
      route.should_not be_nil
      Activr.storage.count_timeline(@timeline, :only => route).should == 1

      route = @timeline.route_for_routing_and_activity('picture_owner', LikePictureActivity)
      route.should_not be_nil
      Activr.storage.count_timeline(@timeline, :only => route).should == 0
    end

    it "deletes all timeline entries" do
      timeline_2 = UserNewsFeedTimeline.new(buddy)
      Activr::Timeline::Entry.new(timeline_2, 'actor_follower', @activity_1).store!
      Activr::Timeline::Entry.new(timeline_2, 'actor_follower', @activity_2).store!

      Activr.storage.count_timeline(@timeline).should == 2
      Activr.storage.count_timeline(timeline_2).should == 2

      # test
      Activr.storage.delete_timeline(@timeline)

      # check
      Activr.storage.count_timeline(@timeline).should == 0
      Activr.storage.count_timeline(timeline_2).should == 2

      # test
      Activr.storage.delete_timeline(timeline_2)

      # check
      Activr.storage.count_timeline(@timeline).should == 0
      Activr.storage.count_timeline(timeline_2).should == 0
    end

    it "deletes timeline entries with :before option" do
      timeline_2 = UserNewsFeedTimeline.new(buddy)
      Activr::Timeline::Entry.new(timeline_2, 'actor_follower', @activity_1).store!
      Activr::Timeline::Entry.new(timeline_2, 'actor_follower', @activity_2).store!

      Activr.storage.count_timeline(@timeline).should == 2

      # test
      Activr.storage.delete_timeline(@timeline, :before => (Time.now.utc - 45))

      # check
      Activr.storage.count_timeline(@timeline).should == 2

      # test
      Activr.storage.delete_timeline(@timeline, :before => (Time.now.utc - 15))

      # check
      Activr.storage.count_timeline(@timeline).should == 1

      # test
      Delorean.jump(30)
      Activr.storage.delete_timeline(@timeline, :before => (Time.now.utc - 15))

      # check
      Activr.storage.count_timeline(@timeline).should == 0

      Activr.storage.count_timeline(timeline_2).should == 2
    end

    it "deletes timeline entries with :entities option" do
      timeline_2 = UserNewsFeedTimeline.new(buddy)
      Activr::Timeline::Entry.new(timeline_2, 'actor_follower', @activity_1).store!
      Activr::Timeline::Entry.new(timeline_2, 'actor_follower', @activity_2).store!

      Activr.storage.count_timeline(@timeline).should == 2

      # test
      Activr.storage.delete_timeline(@timeline, :entities => { :picture => picture._id, :album => album._id })

      # check
      Activr.storage.count_timeline(@timeline).should == 1

      # test
      Activr.storage.delete_timeline(@timeline, :entities => { :actor => user._id })

      # check
      Activr.storage.count_timeline(@timeline).should == 0

      Activr.storage.count_timeline(timeline_2).should == 2
    end

    it "deletes timeline entries referring to an entity model instance" do
      Activr.storage.delete_timeline_entries_for_entity_model(picture)

      # check
      Activr.storage.find_timeline(@timeline, 10).map(&:_id).should == [ @timeline_entry_2._id ]

      Activr.storage.delete_timeline_entries_for_entity_model(user)

      # check
      Activr.storage.find_timeline(@timeline, 10).map(&:_id).should == [ ]
    end

  end


  #
  # Indexes
  #

  it "adds an activity index" do
    col = Activr.storage.driver.activity_collection

    Activr.storage.driver.drop_indexes(col)
    Activr.storage.driver.indexes(col).should == [ "_id_" ]

    # test
    Activr.storage.add_activity_index("foo")

    # check
    Activr.storage.driver.indexes(col).should == [ "_id_", "foo_1" ]

    # test
    Activr.storage.add_activity_index([ "bar", "baz" ])

    # check
    Activr.storage.driver.indexes(col).should == ["_id_", "foo_1", "bar_1_baz_1"]
  end

  it "adds a timeline index" do
    col = Activr.storage.driver.timeline_collection('user_news_feed')

    Activr.storage.driver.drop_indexes(col)
    Activr.storage.driver.indexes(col).should == [ "_id_" ]

    # test
    Activr.storage.add_timeline_index('user_news_feed', "foo")

    # check
    Activr.storage.driver.indexes(col).should == [ "_id_", "foo_1" ]

    # test
    Activr.storage.add_timeline_index('user_news_feed', [ "bar", "baz" ])

    # check
    Activr.storage.driver.indexes(col).should == ["_id_", "foo_1", "bar_1_baz_1"]
  end

  it "create all necessary indexes" do
    activities_col = Activr.storage.driver.activity_collection
    timelines_col  = Activr.storage.driver.timeline_collection('user_news_feed')

    Activr.storage.driver.drop_indexes(activities_col)
    Activr.storage.driver.indexes(activities_col).should == [ "_id_" ]

    Activr.storage.driver.drop_indexes(timelines_col)
    Activr.storage.driver.indexes(timelines_col).should == [ "_id_" ]

    # test
    Activr.storage.create_indexes

    # check
    Activr.storage.driver.indexes(activities_col).should == [ "_id_", "actor_1_at_1", "picture_1_at_1", "album_1_at_1" ]
    Activr.storage.driver.indexes(timelines_col).should  == [ "_id_", "rcpt_1_activity.at_1", "activity.picture_1", "activity.album_1" ]
  end


  #
  # Hooks
  #

  it "runs :will_insert_activity hook" do
    Activr.storage.will_insert_activity do |activity_hash|
      activity_hash['foo'] = 'bar'
    end

    Activr.storage.will_insert_activity do |activity_hash|
      activity_hash['meta'] ||= { }
      activity_hash['meta']['bar'] = 'baz'
    end

    # test
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!
    activity_hash = Activr.storage.driver.find_activity(activity._id)
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
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    activity.store!

    # check
    activity_hash = Activr.storage.driver.find_activity(activity._id)
    activity_hash['foo'].should be_blank
    activity_hash['meta'].should be_blank

    fetched_activity = Activr.storage.find_activity(activity._id)
    fetched_activity[:foo].should == 'bar'
    fetched_activity[:bar].should == 'baz'
  end

  it "runs :will_insert_timeline_entry hook" do
    Activr.storage.will_insert_timeline_entry do |timeline_entry_hash, timeline_class|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['foo'] = 'bar'
    end

    Activr.storage.will_insert_timeline_entry do |timeline_entry_hash, timeline_class|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['bar'] = 'baz'
    end

    # test
    timeline = UserNewsFeedTimeline.new(owner)
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    timeline_entry = Activr::Timeline::Entry.new(timeline, 'album_owner_add_picture', activity)
    timeline_entry.store!

    # check
    timeline_entry_hash = Activr.storage.driver.find_timeline_entry(timeline.kind, timeline_entry._id)
    timeline_entry_hash['meta'].should == {
      'foo' => 'bar',
      'bar' => 'baz',
    }
  end

  it "runs :did_find_timeline_entry hook" do
    Activr.storage.did_find_timeline_entry do |timeline_entry_hash, timeline_class|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['foo'] = 'bar'
    end

    Activr.storage.did_find_timeline_entry do |timeline_entry_hash, timeline_class|
      timeline_entry_hash['meta'] ||= { }
      timeline_entry_hash['meta']['bar'] = 'baz'
    end

    # test
    timeline = UserNewsFeedTimeline.new(owner)
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
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
