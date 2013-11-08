require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Dispatcher do

  let(:user)  { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy) { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:photo) { Picture.create(:title => "Me myself and I") }
  let(:album) { Album.create(:name => "Selfies") }

  it "instanciates" do
    dispatcher = Activr::Dispatcher.new
    dispatcher.should_not be_nil
  end

  it "raises an exception if activity was not previously stored" do
    dispatcher = Activr::Dispatcher.new

    activity = FollowBuddyActivity.new(:actor => user._id, :buddy => buddy._id)

    lambda{ self.dispatcher.route(activity) }.should raise_error
  end

  it "routes to activity path" do
    dispatcher = Activr::Dispatcher.new

    activity = FollowBuddyActivity.new(:actor => user._id, :buddy => buddy._id)
    activity.store!

    # check
    pending("todo")

    # test
    dispatcher.route(activity)
 end

  it "routes to activity entity" do
    # @todo !!!
    pending("todo")
  end

  it "routes with a custom route kind" do
    # @todo !!!
    pending("todo")
  end

  it "routes with predefined routing" do
    # @todo !!!
    pending("todo")
  end

  it "routes with timeline's class method" do
    # @todo !!!
    pending("todo")
  end

end
