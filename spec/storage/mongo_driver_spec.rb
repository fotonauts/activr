require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Activr::Storage::MongoDriver do

  #
  # Indexes
  #

  it "adds an activity index" do
    col = Activr.storage.driver.activity_collection

    Activr.storage.driver.drop_indexes(col)
    Activr.storage.driver.indexes(col).should == [ "_id_" ]

    # test
    Activr.storage.driver.add_activity_index("foo")

    # check
    Activr.storage.driver.indexes(col).should == [ "_id_", "foo_1" ]

    # test
    Activr.storage.driver.add_activity_index([ "bar", "baz" ])

    # check
    Activr.storage.driver.indexes(col).should == ["_id_", "foo_1", "bar_1_baz_1"]
  end

  it "adds a timeline index" do
    col = Activr.storage.driver.timeline_collection('user_news_feed')

    Activr.storage.driver.drop_indexes(col)
    Activr.storage.driver.indexes(col).should == [ "_id_" ]

    # test
    Activr.storage.driver.add_timeline_index('user_news_feed', "foo")

    # check
    Activr.storage.driver.indexes(col).should == [ "_id_", "foo_1" ]

    # test
    Activr.storage.driver.add_timeline_index('user_news_feed', [ "bar", "baz" ])

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
    Activr.storage.driver.create_indexes

    # check
    Activr.storage.driver.indexes(activities_col).should == [ "_id_", "actor_1_at_1", "picture_1_at_1", "album_1_at_1" ]
    Activr.storage.driver.indexes(timelines_col).should  == [ "_id_", "rcpt_1_activity.at_1", "activity.picture_1", "activity.album_1" ]
  end

end
