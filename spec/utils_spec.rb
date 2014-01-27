require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Utils do

  it "computes kind from a class" do
    Activr::Utils.kind_for_class(AddPictureActivity).should == 'add_picture_activity'
  end

  it "computes kind from a class with a suffix" do
    Activr::Utils.kind_for_class(AddPictureActivity, 'activity').should == 'add_picture'
  end

  it "computes class from a kind" do
    Activr::Utils.class_for_kind('add_picture_activity').should == AddPictureActivity
  end

  it "computes class from a kind with a suffix" do
    Activr::Utils.class_for_kind('add_picture', 'activity').should == AddPictureActivity
  end

end
