Activr
======

Activr is the Ruby gem created by Fotonauts to manage Activity Feeds on [Fotopedia](http://www.fotopedia.com).

Some magic is invoked when running inside a [Rails](http://www.rubyonrails.com) application but Activr can be used without Rails.

A demo app is available [on github](https://github.com/fotonauts/activr_demo).

Activities are stored in a [MongoDB](http://www.mongodb.org/) database.


Install
=======

```bash
$ [sudo] gem install activr
```

In Rails, add it to your Gemfile:

```
gem 'activr'
```


Quick start
===========

Define an activity
------------------

An activity is an event that is (most of the time) performed by a user in your application.

When defining an activity you specify allowed entities and a humanization template.

Let's generate our first activity that will be dispatched when a user adds a picture to an album:

```bash
$ rails g activr:activity add_picture actor:User picture album
```

The file `app/activities/add_picture_activity.rb` is created:

```ruby
class AddPictureActivity < Activr::Activity

  entity :actor, :class => User, :humanize => :fullname
  entity :picture, :humanize => :title
  entity :album, :humanize => :name

  humanize "{{{actor}}} add picture {{{picture}}} {{{album}}}"

end
```

An entity represents one of your application's model involved the activity.

Entity's class is inferred thanks to entity name, so by default the `:picture` entity have the `Picture` class, but you can still provide the `:class` option to specify another class.

By convention, the entity that correspond to the user performing the action should be named `:actor`.

The `humanize` method defines a sentence that describes the activity and it is a [Mustache](http://mustache.github.io) template. Let's change the generated sentence by a better one:

```ruby
  humanize "{{{actor}}} added picture {{{picture}}} to the album {{{album}}}"
```

The `:humanize` option on entity correspond to a method that is called on corresponding entity's instance to humanize it. Note that the generator tries to find by itself that method.

Here is an example of activity instanciation and humanization:

```ruby
user    = User.create!({ :_id => 'john', :first_name => "John", :last_name => "WILLIAMS"})
picture = Picture.create!({ :_id => 'my_face', :title => "My Face"})
album   = Album.create!({ :name => "My Selfies"})

activity = AddPictureActivity.new(:actor => user, :picture => picture, :album => album)

activity.humanize
# => John WILLIAMS added picture My Face to the album My Selfies

activity.humanize(:html => true)
# => <a href="/users/john">John WILLIAMS</a> added picture <a href="/pictures/my_face">My Face</a> to the album <a href="/albums/5295bc9261796d649f080000">My Selfies</a>
```


Dispatch an activity
--------------------

You can now dispatch that activity in your application when a picture is added to an album:

```ruby
class Album

  include Mongoid::Document

  field :name, :type => String
  has_and_belongs_to_many :pictures, :class_name => "Picture", :inverse_of => :albums

  def add_picture(picture, user)
    unless self.pictures.include?(picture)
      self.pictures << picture

      # dispatch activity
      Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => self))
    end
  end

end
```

For reference, the corresponding controller code is:

```ruby
class AlbumsController < ApplicationController

  # ...

  def create_picture
    @album = Album.find(params[:id])

    # create picture
    picture = Picture.create!(picture_params)

    # add picture to album
    @album.add_picture(picture, current_user)

    flash[:success] = "Picture '#{picture.title}' added to album: '#{@album.name}'"
    redirect_to @album
  end

  private

  def picture_params
    params.require(:picture).permit(:title, :image)
  end

end
```

Once dispatched the activity is stored in the `activities` MongoDB collection:

```
> db.activities.findOne()
{
  "_id" : ObjectId("5295bc9f61796d649f140000"),
  "at" : ISODate("2013-11-27T09:34:23.850Z"),
  "kind" : "add_picture",
  "actor" : "john",
  "picture" : "my_face",
  "album" : ObjectId("5295bc9261796d649f080000")
}
```


Basic Activity feeds
--------------------

Several basic activity feeds are now available:

- the global feed: all activities in your application
- per entity feed: each entity involved in an activity have its own activity feed


### Global Activity Feed

Use `Activr#activities` to fetch the latest activities in your application:

```ruby
puts "There are #{Activr.activities_count} activites. Here are the 10 most recent:"

activities = Activr.activities(10)
activities.each do |activity|
  puts activity.humanize
end
```

Note that you can paginate thanks to the `:skip` option of the `#activities` method.


### Actor Activity Feed

To fetch actor's activities, include the mixin `Activr::Entity::ModelMixin` into your actor's class:

```ruby
class User

  # inject sugar methods
  include Activr::Entity::ModelMixin

  include Mongoid::Document

  field :_id, :type => String
  field :first_name, :type => String
  field :last_name, :type => String

  def fullname
    "#{self.first_name} #{self.last_name}"
  end

end
```

Now the `User` class have two new methods: `#activities` and `#activities_count`:

```ruby
user = User.find('john')

puts "#{user.fullname} have #{user.activities_count} activites. Here are the 10 most recent:"

user.activities(10).each do |activity|
  puts activity.humanize
end
```


### Album Activity Feed

You can too fetch a per-album activity feed by including the mixin `Activr::Entity::ModelMixin` into the `Album` class:

```ruby
class Album

  # inject sugar methods
  include Activr::Entity::ModelMixin

  include Mongoid::Document

  field :name, :type => String
  has_and_belongs_to_many :pictures, :class_name => "Picture", :inverse_of => :albums

  def add_picture(picture, user)
    unless self.pictures.include?(picture)
      self.pictures << picture

      # dispatch activity
      Activr.dispatch!(AddPictureActivity.new(:actor => user, :picture => picture, :album => self))
    end
  end

end
```

Example:

```ruby
album = Album.find(BSON::ObjectId.from_string('5295bc9261796d649f080000'))

puts "There are #{album.activities_count} activites in the album #{album.name}. Here are the 10 most recent:"

album.activities(10).each do |activity|
  puts activity.humanize
end
```


News Feed
---------

Now we want a User News Feed, so that each user can get news from friends they follow and from albums they own or follow. That's the goal of a *timeline*: to create a complex activity feed.


### Timeline

Let's generate a timeline class:

```bash
$ rails g activr:timeline user_news_feed User
```

The file `app/timelines/user_news_feed_timeline.rb` is created:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  recipient User


  #
  # Routes
  #

  # route FollowBuddyActivity, :to => 'buddy', :humanize => "{{{actor}}} is now following you"


  #
  # Callbacks
  #

  def should_handle_activity?(activity, route)
    # return `false` to skip activity routing
    true
  end

  def should_store_timeline_entry?(timeline_entry)
    # return `false` to cancel timeline entry storing
    true
  end

  def will_store_timeline_entry(timeline_entry)
    # this is your last chance to modify timeline entry before it is stored
  end

  def did_store_timeline_entry(timeline_entry)
    # the timeline entry was stored, can now do some post-processing
  end

end
```

When defining a `Timeline` class you specify:

  - what model in your application *owns* that timeline: the `recipient`
  - what activities are displayed in that timeline: the `routes`


### Routes

Let's add some routes:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  recipient User

  # this is a predefined routing, to fetch all followers of an activity's actor
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }


  #
  # Routes
  #

  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"

  # predefined routing: users will see in their news feed when a friend they follow likes a picture
  route AddPictureActivity, :using => :actor_follower

  # method call: users will see in their news feed when someone adds a picture in an album they follow
  route AddPictureActivity, :using => :album_follower


  # define a routing with a class method, to fetch all followers of an activity's album
  def self.album_follower(activity)
    activity.album.followers
  end

  # ...

end
```

As you can see there as several ways to define a route:

#### with an *activity path*

```ruby
  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"
```

The *path* is specified with the `:to` route's setting. It describes a method chaining to call on dispatched activities.

So with our example the route is resolved that way:

```ruby
  album = activity.album
  recipient = album.owner
```

#### with a *predefined routing*

First, declare a predefined `routing`:

```ruby
  # this is a predefined routing, to fetch all followers of an activity's actor
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }
```

Then use it with the `:using` route's setting:

```ruby
  # predefined routing: users will see in their news feed when a friend they follow likes a picture
  route AddPictureActivity, :using => :actor_follower
```

#### with a call on timeline class method

You can resolve a route with a timeline class method: 

```ruby
  # define a routing with a class method, to fetch all followers of an activity's album
  def self.album_follower(activity)
    activity.album.followers
  end
```

Then use it with the `:using` route's setting:

```ruby
  # method call: users will see in their news feed when someone adds a picture in an album they follow
  route AddPictureActivity, :using => :album_follower
```

For the sake of demonstration you can see all three ways in previous code example, but when a route is simple to resolve it is preferred to use a *activity path* like that:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  recipient User


  #
  # Routes
  #

  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"

  # predefined routing: users will see in their news feed when a friend they follow likes a picture
  route AddPictureActivity, :to => 'actor.followers'

  # method call: users will see in their news feed when someone adds a picture in an album they follow
  route AddPictureActivity, :to => 'album.followers'

  # ...

end
```


### Timeline Entry

When an activity is routed to a timeline, that activity is copied to a *Timeline Entry* that is then stored in database.

So Activr uses a *Fanout on write* mecanism to dispatch activities to timelines.

A timeline entry is stored in the `<timeline kind>_timelines` MongoDB collection.

For example, Corinne receives previously generated activity because John added a picture to an album owned by Corinne:

```
> db.user_news_feed_timelines.findOne()
{
  "_id" : ObjectId("5295c06b61796d673b010000"),
  "rcpt" : "corinne",
  "routing" : "album_owner",
  "activity" : {
    "_id" : ObjectId("5295bc9f61796d649f140000"),
    "at" : ISODate("2013-11-27T09:34:23.850Z"),
    "kind" : "add_picture",
    "actor" : "john",
    "picture" : "my_face",
    "album" : ObjectId("5295bc9261796d649f080000")
  }
}
```

As you can see, a Timeline Entry contains:

- a copy of the original activity
- the recipient id `rcpt`
- the `routing` kind: `album_owner` means that Corinne received that activity in her News Feed because she is the owner of the album

You can add too any meta data. So for example you can add a `read` meta data if you want to implemented a read/unread mecanism in your News Feed.

Specify a `:humanize` setting on a `route` to specialize humanization of corresponding timeline entries. For example:

```ruby
  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"
```

If you don't set a `:humanize` setting then the humanization of the embedded activity is used instead.


### Callbacks

Several callbacks are invoked on timeline instance during the activity handling workflow:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  # ...

  #
  # Callbacks
  #

  def should_handle_activity?(activity, route)
    # return `false` to skip activity routing
    true
  end

  def should_store_timeline_entry?(timeline_entry)
    # return `false` to cancel timeline entry storing
    true
  end

  def will_store_timeline_entry(timeline_entry)
    # this is your last chance to modify timeline entry before it is stored
  end

  def did_store_timeline_entry(timeline_entry)
    # the timeline entry was stored, can now do some post-processing
    # for example you can send notifications
  end

end
```


### Display

Two methods are injected in the timeline recipient class: `#news_feed` and `#news_feed_count`:

```ruby
class UsersController < ApplicationController

  def news_feed
    user = User.find(params[:id])

    @news_feed       = user.user_news_feed(10)
    @news_feed_count = user.user_news_feed_count
  end

end
```

Here is simple view:

```erb
  <p>
    You have <%= @news_feed_count %> entries in your News Feed. Here are the 10 most recent:
  </p>
  <ul id='news_feed'>
    <% @news_feed.each do |timeline_entry| %>
      <li><%= raw timeline_entry.humanize(:html => true) %></li>
    <% end %>
  </ul>
<% end %>
```

Here is a more realistic view:

```erb
<div id='news_feed'>
  <% @news_feed.each do |timeline_entry| %>
    <% activity = timeline_entry.activity %>
    <div class="activity <%= activity.kind %>">
      <div class="icon">
        <%= link_to(image_tag(activity.actor.avatar.thumb.url, :title => activity.actor.fullname), activity.actor) %>
      </div>
      <div class="content">
        <div class="title"><%= timeline_entry.humanize(:html => true).html_safe %></div>
        <% if activity.buddy %>
          <div class="buddy">
            <%= link_to(image_tag(activity.buddy.avatar.url, :title => activity.buddy.fullname), activity.buddy) %>
          </div>
        <% elsif activity.picture %>
          <div class="picture">
            <%= link_to(image_tag(activity.picture.image.small.url, :title => activity.picture.title), activity.picture) %>
          </div>
        <% elsif activity.album %>
          <div class="album">
            <%= link_to(image_tag(activity.album.cover.image.small.url, :title => activity.album.name), activity.album) %>
          </div>
        <% end %>
        <small class="date text-muted"><%= distance_of_time_in_words_to_now(activity.at, true) %> ago</small>
      </div>
    </div>
  <% end %>
</div>
```


Async
=====

Activr permits you to plug any job system to run some part if Activr's code asynchronously.

Possible hooks are:

  - `:route_activity` - An activity must me routed by the Dispatcher
  - `:timeline_handle` - An activity must be handled by a timeline

For example, here is the default `:route_activity` hook handler when [Resque](https://github.com/resque/resque) is detected in a Rails application:


```ruby
# config
Activr.configure do |config|
  config.async[:route_activity] ||= Activr::Async::Resque::RouteActivity
end
```

```ruby
class Activr::Async::Resque::RouteActivity
  @queue = 'activr_route_activity'

  class << self
    def enqueue(activity)
      ::Resque.enqueue(self, activity.to_hash)
    end

    def perform(activity_hash)
      # unserialize argument
      activity_hash = Activr::Activity.unserialize_hash(activity_hash)
      activity = Activr::Activity.from_hash(activity_hash)

      # call hook
      Activr::Async.route_activity(activity)
    end
  end # class << self
end # class RouteActivity
```

A hook class:

  - must implement a `#enqueue` method, used to enqueue the async job
  - must call `Activr::Async.<hook_name>` method in the async job

Hook classes to use are specified thanks to the `config.async` hash.


Indexes
=======

@todo


Todo
====

- Trim timelines
- Activities aggregation in timelines
- Remove duplicate activities in a given period of time
- Rails generators to setup indexes
- Rails generator to setup basic views
- Rails generator to setup admin controllers
- Permits "Fanout on read" for inactive users, to preserve db size
- Permits "Fanout on write with buckets", for maximum read perfs


References
==========

- <http://blog.mongodb.org/post/65612078649/using-mongodb-schema-design-to-create-inboxes>
- <http://www.slideshare.net/danmckinley/etsy-activity-feeds-architecture>


Credits
=======

Aymerick Jéhanne [@aymerick](https://twitter.com/aymerick) at Fotonauts.

Copyright (c) 2013 Fotonauts released under the MIT license.
