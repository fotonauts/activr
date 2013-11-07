require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr do

  it "have a configuration" do
    Activr.config.sync.should be_true # default is true for unit testing
    Activr.config.foo.should be_nil
  end

  it "modifies configuration" do
    Activr.config.sync = true
    Activr.config.sync.should be_true

    Activr.config.foo = :bar
    Activr.config.foo.should == :bar
  end

end
