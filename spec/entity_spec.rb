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

  it "humanizes" do
    entity = Activr::Entity.new(:actor, user, :class => User, :humanize => :fullname)

    entity.humanize.should == "Jean PALE"
  end

  it "humanizes to :default option if model have no humanization field" do
    entity = Activr::Entity.new(:actor, user, :class => User, :default => 'Mr Proutman')

    entity.humanize.should == "Mr Proutman"
  end

  it "humanizes to :default option if model humanization is nil" do
    entity = Activr::Entity.new(:actor, user, :class => User, :humanize => :nil_field, :default => 'Mr Proutman')

    entity.humanize.should == "Mr Proutman"
  end

  it "humanizes to :default option if model humanization is blank" do
    entity = Activr::Entity.new(:actor, user, :class => User, :humanize => :blank_meth, :default => 'Miss Proutman')

    entity.humanize.should == "Miss Proutman"
  end

  it "humanizes to an empty string if no humanization is possible" do
    entity = Activr::Entity.new(:actor, user, :class => User)

    entity.humanize.should == ""
  end

  it "humanizes to :html thanks to :htmlize option" do
    entity = Activr::Entity.new(:actor, user, :class => User, :humanize => :fullname, :htmlize => :to_html)

    entity.humanize(:html => true).should == "<span class='user'>Jean PALE<span>"
  end

  it "sanitize entity value when humanizing to :html" do
    pending("Setup a dummy Rails application in specs")

    entity = Activr::Entity.new(:actor, user, :class => User, :default => "<script>alert('p0Wn3d');</script>")

    entity.humanize(:html => true).should == "&lt;span class='user'&gt;alert('p0Wn3d');&lt;span&gt;"
  end

end
