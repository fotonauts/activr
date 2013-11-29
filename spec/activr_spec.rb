require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr do

  let(:user)     { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }
  let(:buddy)    { User.create(:_id => 'justine', :first_name => "Justine", :last_name => "CHTITEGOUTE") }
  let(:photo)    { Picture.create(:title => "Me myself and I") }
  let(:album)    { Album.create(:name => "Selfies") }
  let(:owner)    { User.create(:_id => 'corinne', :first_name => "Corinne", :last_name => "CHTITEGOUTE") }
  let(:follower) { User.create(:_id => 'anne', :first_name => "Anne", :last_name => "CHTITEGOUTE") }

  after(:each) do
    Activr.config.async = false
  end

  it "have a configuration" do
    Activr.config.async.should be_false
    Activr.config.foo.should be_nil
  end

  it "modifies configuration" do
    Activr.config.async = true
    Activr.config.async.should be_true

    Activr.config.foo = :bar
    Activr.config.foo.should == :bar
  end

end
