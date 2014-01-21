require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Storage do

  let(:user)    { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:picture) { Picture.create(:title => "Me myself and I") }
  let(:album)   { Album.create(:name => "Selfies") }
  let(:owner)   { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }
  let(:buddy)   { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }

  after(:each) do
    Activr.storage.clear_hooks!
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


  #
  # Activities
  #

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

  end


  #
  # Timelines
  #

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

  end

end
