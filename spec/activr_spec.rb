require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr do

  let(:user)     { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:user_2)   { User.create(:_id => 'proutman', :first_name => "Prout", :last_name => "MAN") }
  let(:buddy)    { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:picture)  { Picture.create(:title => "Me myself and I") }
  let(:album)    { Album.create(:name => "Selfies") }
  let(:owner)    { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }
  let(:follower) { User.create(:_id => 'anne', :first_name => "Anne", :last_name => "CHTITEGOUTE") }

  after(:each) do
    Activr.config.async = { }
  end

  it "has a configuration" do
    Activr.config.async.should be_blank
    Activr.config.foo.should be_nil
  end

  it "is configurable" do
    Activr.configure do |config|
      config.async[:route_activity] = 'bar'
      config.foo = :bar
    end

    Activr.config.async.should == { :route_activity => 'bar'}
    Activr.config.foo.should == :bar
  end

  it "setups registry" do
    # note: setup was already done in spec_helper.rb
    # Activr.setup

    Activr.registry.entity_classes.should_not be_blank
    Activr.registry.activity_entities.should_not be_blank
  end

  it "computes activities path" do
    Activr.activities_path.should == File.join(File.dirname(__FILE__), "app", "activities")
  end

  it "computes timelines path" do
    Activr.timelines_path.should == File.join(File.dirname(__FILE__), "app", "timelines")
  end

  it "dispatches activities" do
    # @todo FIXME
    user.followers = [ follower ]

    Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => album))

    Activr.timeline(UserNewsFeedTimeline, follower).dump.should == [
      "Jean PALE added picture Me myself and I to the album Selfies"
    ]
  end

  it "stores activities when dispatching" do
    activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

    activity.should_not be_stored

    Activr.dispatch!(activity)

    activity.should be_stored
  end

  it "fetches activities" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    Activr.dispatch!(activity_1)

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user_2, :buddy => buddy)
    Activr.dispatch!(activity_2)

    Delorean.jump(30)

    activity_3 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    Activr.dispatch!(activity_3)

    Delorean.jump(30)

    fetched_activities = Activr.activities(1)
    fetched_activities.size.should == 1
    fetched_activities.first._id.should == activity_3._id

    fetched_activities = Activr.activities(2)
    fetched_activities.size.should == 2
    fetched_activities[0]._id.should == activity_3._id
    fetched_activities[1]._id.should == activity_2._id

    fetched_activities = Activr.activities(4)
    fetched_activities.size.should == 3
    fetched_activities[0]._id.should == activity_3._id
    fetched_activities[1]._id.should == activity_2._id
    fetched_activities[2]._id.should == activity_1._id
  end

  it "fetches activities with specified entity" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    Activr.dispatch!(activity_1)

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user_2, :buddy => buddy)
    Activr.dispatch!(activity_2)

    Delorean.jump(30)

    activity_3 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    Activr.dispatch!(activity_3)

    Delorean.jump(30)

    fetched_activities = Activr.activities(10, :entities => { :actor => user._id })
    fetched_activities.size.should == 2
    fetched_activities[0]._id.should == activity_3._id
    fetched_activities[1]._id.should == activity_1._id

    fetched_activities = Activr.activities(10, :entities => { :buddy => buddy._id })
    fetched_activities.size.should == 2
    fetched_activities[0]._id.should == activity_3._id
    fetched_activities[1]._id.should == activity_2._id

    fetched_activities = Activr.activities(10, :entities => { :picture => picture._id })
    fetched_activities.size.should == 1
    fetched_activities[0]._id.should == activity_1._id
  end

  it "normalize query options when fetching activities" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    Activr.dispatch!(activity_1)

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user_2, :buddy => buddy)
    Activr.dispatch!(activity_2)

    Delorean.jump(30)

    activity_3 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    Activr.dispatch!(activity_3)

    Delorean.jump(30)

    fetched_activities = Activr.activities(10, :actor => user._id)
    fetched_activities.size.should == 2
    fetched_activities[0]._id.should == activity_3._id
    fetched_activities[1]._id.should == activity_1._id

    fetched_activities = Activr.activities(10, :buddy => buddy._id)
    fetched_activities.size.should == 2
    fetched_activities[0]._id.should == activity_3._id
    fetched_activities[1]._id.should == activity_2._id

    fetched_activities = Activr.activities(10, :picture => picture._id)
    fetched_activities.size.should == 1
    fetched_activities[0]._id.should == activity_1._id
  end

  it "counts activities" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    Activr.dispatch!(activity_1)

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user_2, :buddy => buddy)
    Activr.dispatch!(activity_2)

    Delorean.jump(30)

    activity_3 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    Activr.dispatch!(activity_3)

    Delorean.jump(30)

    Activr.activities_count.should == 3
  end

  it "counts activities with specified entity" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    Activr.dispatch!(activity_1)

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user_2, :buddy => buddy)
    Activr.dispatch!(activity_2)

    Delorean.jump(30)

    activity_3 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    Activr.dispatch!(activity_3)

    Delorean.jump(30)

    Activr.activities_count(:entities => { :actor => user._id }).should == 2
    Activr.activities_count(:entities => { :actor => user_2._id }).should == 1
    Activr.activities_count(:entities => { :picture => picture._id }).should == 1
    Activr.activities_count(:entities => { :album => album._id }).should == 1
  end

  it "normalize query options when counting activities" do
    activity_1 = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)
    Activr.dispatch!(activity_1)

    Delorean.jump(30)

    activity_2 = FollowBuddyActivity.new(:actor => user_2, :buddy => buddy)
    Activr.dispatch!(activity_2)

    Delorean.jump(30)

    activity_3 = FollowBuddyActivity.new(:actor => user, :buddy => buddy)
    Activr.dispatch!(activity_3)

    Delorean.jump(30)

    Activr.activities_count(:actor => user._id).should == 2
    Activr.activities_count(:actor => user_2._id).should == 1
    Activr.activities_count(:picture => picture._id).should == 1
    Activr.activities_count(:album => album._id).should == 1
  end

  it "instanciate timelines" do
    timeline = Activr.timeline(UserNewsFeedTimeline, user)

    timeline.class.should == UserNewsFeedTimeline
    timeline.recipient_id.should == user._id
  end

  it "renders a sentence" do
    Activr.sentence("I like to {{verb}} it {{verb}} it", { :verb => 'move' })
  end

  it "strip whitespaces when rendering an activity sentence" do
    Activr.sentence("   We like to ! {{verb}} it !     ", { :verb => 'move' })
  end

end
