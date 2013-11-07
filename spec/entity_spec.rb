require File.join(File.dirname(__FILE__), 'spec_helper')

describe Activr::Entity do

  let(:user) { User.create(:_id => 'jpale', :first_name => "Jean", :last_name => "PALE") }

  it "instanciates with model instance" do
    entity = Activr::Entity.new(:actor, user)

    entity.name.should == :actor
    entity.model_class.should == User
    entity.model.should == user
    entity.model_id.should == user._id
  end

  it "instanciates with model id" do
    entity = Activr::Entity.new(:actor, user._id, :class => User)

    entity.name.should == :actor
    entity.model_class.should == User
    entity.model.should == user
    entity.model_id.should == user._id
  end

  it "raises if instanciated with a model id but without a :class option" do
    lambda { Activr::Entity.new(:actor, user._id) }.should raise_error
  end

  it "raises if instanciated with a :class option different from the model instance provided" do
    lambda { Activr::Entity.new(:actor, user, :class => Picture) }.should raise_error
  end

end
