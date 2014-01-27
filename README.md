# WARNING: This is BETA code, please stay tuned for the upcoming 1.0 version


Activr
======

Activr is the Ruby gem created by Fotonauts to manage activity feeds on [Fotopedia](http://www.fotopedia.com).

With Activr you can create:

- a Global Activity Feed to display all activities in your website in a single feed
- a User Activity Feed to display all actions performed by a specific user
- a User News Feeds so thar each user can get news from friends they follow, from albums they own or follow, etc.
- an Album Activity Feed to display what happens in a specific album
- ...

Activities are stored in a [MongoDB](http://www.mongodb.org/) database.

Some magic is invoked when running inside a [Rails](http://www.rubyonrails.com) application but Activr can be used without Rails.

If [Resque](https://github.com/resque/resque) is detected in a Rails application then it is automatically used to run some parts of Activr code asynchronously.

A demo app is available [on heroku](http://activr-demo.herokuapp.com), feel free to create an account and try it. Demo source code is [on github](https://github.com/fotonauts/activr_demo) too.

- More information [on our tumblr](http://fotopedia-code.tumblr.com)
- Source code [on github](http://github.com/fotonauts/activr)
- Code documentation [on rubydoc](http://rubydoc.info/github/fotonauts/activr/frames)

[![Build Status](https://travis-ci.org/fotonauts/activr.png)](https://travis-ci.org/fotonauts/activr)


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


### Entities

An entity represents one of your application models that is involved in the activity.

By convention, the entity that corresponds to the user performing the action should be named `:actor`.

The entity class is inferred thanks to entity name, so by default the `:picture` entity has the `Picture` class, but you can still provide the `:class` option to specify another class.


### Activity humanization

The `humanize` method defines a sentence that describes the activity and it is a [Mustache](http://mustache.github.io) template. Let's change the generated sentence by a better one:

```ruby
  humanize "{{{actor}}} added picture {{{picture}}} to the album {{{album}}}"
```

The `:humanize` option on entity corresponds to a method that is called on the entity instance to humanize it. Note that the generator tries to find that method by itself.


### Usage

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

You can now dispatch this activity in your application when a picture is added to an album:

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


Basic activity feeds
--------------------

Several basic activity feeds are now available:

- the global feed: all activities in your application
- per entity feed


### Global activity feed

Use `Activr#activities` to fetch the latest activities in your application:

```ruby
puts "There are #{Activr.activities_count} activites. Here are the 10 most recent:"

activities = Activr.activities(10)
activities.each do |activity|
  puts activity.humanize
end
```

Note that you can paginate thanks to the `:skip` option of the `#activities` method.


### Entity activity feed

Each entity involved in an activity can have its own activity feed.

To activate entity activity feed, include the mixin `Activr::Entity::ModelMixin` into the corresponding model class, and setup the `:feed_index` option:

```ruby
  include Activr::Entity::ModelMixin

  activr_entity :feed_index => true
```

Then launch the task that setup indexes on the `activities` collection:

```
$ rake activr:create_indexes
```


#### Example: actor activity feed

To fetch actor activities, include the mixin `Activr::Entity::ModelMixin` into your actor class:

```ruby
class User

  # inject sugar methods
  include Activr::Entity::ModelMixin

  activr_entity :feed_index => true

  include Mongoid::Document

  field :_id, :type => String
  field :first_name, :type => String
  field :last_name, :type => String

  def fullname
    "#{self.first_name} #{self.last_name}"
  end

end
```

Now the `User` class has two new methods: `#activities` and `#activities_count`:

```ruby
user = User.find('john')

puts "#{user.fullname} have #{user.activities_count} activites. Here are the 10 most recent:"

user.activities(10).each do |activity|
  puts activity.humanize
end
```


#### Example: album activity feed

You can also fetch a per-album activity feed by including the mixin `Activr::Entity::ModelMixin` into the `Album` class:

```ruby
class Album

  # inject sugar methods
  include Activr::Entity::ModelMixin

  activr_entity :feed_index => true

  # ...

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

Now we want a User News Feed, so that each user can get news from friends he follows and from albums he owns or follows. That is the goal of a timeline: to create a complex activity feed.


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

  # def self.should_route_activity?(activity)
  #   # return `false` to cancel activity routing
  #   true
  # end

  # def should_handle_activity?(activity, route)
  #   # return `false` to skip routed activity
  #   true
  # end

  # def should_store_timeline_entry?(timeline_entry)
  #   # return `false` to cancel timeline entry storing
  #   true
  # end

  # def will_store_timeline_entry(timeline_entry)
  #   # this is your last chance to modify timeline entry before it is stored
  # end

  # def did_store_timeline_entry(timeline_entry)
  #   # the timeline entry was stored, you can now do some post-processing
  # end

end
```

When defining a `Timeline` class you specify:

  - what model in your application _owns_ that timeline: the `recipient`
  - which activities are displayed in that timeline: the `routes`


### Routes

Routes describe which activities must be stored in the timeline and how to resolve recipients for those activities.

When an activity is dispatched, Activr tries to resolve all routes of every timeline with that activity. The result of a route resolving must be either an array of recipient instances/ids or a unique recipient instance/id.

Let's add some routes:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  recipient User

  # this is a predefined routing, to fetch all followers of an activity actor
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }

  # define a routing with a class method, to fetch all followers of an activity album
  def self.album_follower(activity)
    activity.album.followers
  end


  #
  # Routes
  #

  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner'

  # predefined routing: users will see in their news feed when a friend they follow likes a picture
  route AddPictureActivity, :using => :actor_follower

  # method call: users will see in their news feed when someone adds a picture in an album they follow
  route AddPictureActivity, :using => :album_follower


  # ...

end
```

As you can see there are several ways to define a route:

#### Route with an activity path

```ruby
  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner'
```

The _path_ is specified with the `:to` route setting. It describes a method chaining to call on dispatched activities.

So with our example the route is resolved that way:

```ruby
  album = activity.album
  recipient = album.owner
```

#### Route with a predefined routing

First, declare a predefined `routing`:

```ruby
  # this is a predefined routing, to fetch all followers of an activity actor
  routing :actor_follower, :to => Proc.new{ |activity| activity.actor.followers }
```

Then use it with the `:using` route setting:

```ruby
  # predefined routing: users will see in their news feed when a friend they follow likes a picture
  route AddPictureActivity, :using => :actor_follower
```

Note that you can also use a block syntax:

```ruby
  routing :actor_follower do |activity|
    activity.actor.followers
  end
```

#### Route with a call on timeline class method

You can resolve a route with a timeline class method:

```ruby
  # define a routing with a class method, to fetch all followers of an activity album
  def self.album_follower(activity)
    activity.album.followers
  end
```

Then use it with the `:using` route setting:

```ruby
  # method call: users will see in their news feed when someone adds a picture in an album they follow
  route AddPictureActivity, :using => :album_follower
```

#### Preferred route syntax

For the sake of demonstration you can see the three ways in previous timeline code example, but when a route is simple to resolve it is preferred to use an _activity path_ like that:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  recipient User


  #
  # Routes
  #

  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner'

  # predefined routing: users will see in their news feed when a friend they follow likes a picture
  route AddPictureActivity, :to => 'actor.followers'

  # method call: users will see in their news feed when someone adds a picture in an album they follow
  route AddPictureActivity, :to => 'album.followers'

  # ...

end
```


### Timeline Entry

When an activity is routed to a timeline, that activity is copied to a _Timeline Entry_ that is then stored into database (so Activr uses a _Fanout on write_ mecanism to dispatch activities to timelines).

A routed timeline entry is stored in the `<timeline kind>_timelines` MongoDB collection.

For example, Corinne received the previously generated activity because John added a picture to an album she owns:

```
> db.user_news_feed_timelines.findOne({"rcpt": "corinne"})
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
- the recipient id: `rcpt`
- the `routing` kind: here, `album_owner` means that Corinne received that activity in her News Feed because she is the owner of the album

You can also add meta data. For example you may add a `read` meta data if you want to implement a read/unread mecanism in your News Feed.

When you create a new timeline class don't forget to launch the task that setup indexes in the corresponding `timelines` collection:

```
$ rake activr:create_indexes
```


#### Timeline Entry humanization

Specify a `:humanize` setting on a `route` to specialize humanization of corresponding timeline entries. For example:

```ruby
  # activity path: users will see in their news feed when someone adds a picture in one of their albums
  route AddPictureActivity, :to => 'album.owner', :humanize => "{{{actor}}} added a picture to your album {{{album}}}"
```

If you do not set a `:humanize` setting then the humanization of the embedded activity is used instead.


### Callbacks

Several callbacks are invoked on timeline instance so you can hook your own code during the activity dispatching workflow:

```ruby
class UserNewsFeedTimeline < Activr::Timeline

  # ...

  #
  # Callbacks
  #

  def self.should_route_activity?(activity)
    # if you return `false` then nobody will receive that activity for that timeline class
    true
  end

  def should_handle_activity?(activity, route)
    # if you return `false` then current recipient won't receive that routed activity
    true
  end

  def should_store_timeline_entry?(timeline_entry)
    # if you return `false` then current recipient won't receive that timeline entry
    true
  end

  def will_store_timeline_entry(timeline_entry)
    # this is your last chance to modify timeline entry before it is stored
  end

  def did_store_timeline_entry(timeline_entry)
    # the timeline entry was stored, you can now do some post-processing
    # for example you can send notifications
  end

end
```


### Fetching / Display

Two methods are injected in the timeline recipient class: `#<timeline_kind>` and `#<timeline_kind>_count`. So in our case: `#user_news_feed` and `#user_news_feed_count`:

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

Here is a view taken from [Activr Demo](https://github.com/fotonauts/activr_demo):

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
        <small class="date text-muted"><%= distance_of_time_in_words_to_now(activity.at, :include_seconds => true) %> ago</small>
      </div>
    </div>
  <% end %>
</div>
```


Entity model deletion
=====================

When one of your entities models instance is deleted you should probably call the `delete_activities!` method. This method deletes all activities that refer to the deleted entity from the `activities` and `timelines` collections.

You should too add `activr_entity :deletable => true` to your model class to ensure that a deletion index is correctly setup when running the `rake activr:create_indexes` task.

```ruby
class Picture

  include Activr::Entity::ModelMixin

  # picture can be deleted
  activr_entity :deletable => true

  include Mongoid::Document

  # ...

  # delete all activities
  after_destroy :delete_activities!

end
```


Async
=====

You can plug a job system to run some parts of Activr code asynchronously.

Possible hooks are:

  - `:route_activity` - Activity is routed by the dispatcher
  - `:timeline_handle` - Activity is handled by a timeline

For example, here is the default `:route_activity` hook handler that is provided out of the box when [Resque](https://github.com/resque/resque) is detected in a Rails application:


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

  - implements an `#enqueue` method, used to enqueue the async job
  - calls `Activr::Async.<hook_name>` method in the async job

Hook classes are specified thanks to the `config.async` hash.

If you are writing a Rails application you just need to add the `Resque` gem to your `Gemfile` to enable async hooks. If you want to use another job system then you have to write your own async hook handlers. If you want to force disabling of async hooks, for example when deploying your app on Heroku with only one dyno, just set the environment variable `ACTIVR_FORCE_SYNC` to `true`.


Railties
========

The default mongodb connection uri is `mongodb://127.0.0.1/activr`, but if you are using Activr inside a Rails application with mongoid gem loaded then the mongoid database connection will be used instead. If you don't want that behaviour then set the environment variable  `ACTIVR_SKIP_MONGOID_RAILTIE` to `true`, or set the [Fwissr](https://github.com/fotonauts/fwissr) key `/activr/skip_mongoid_railtie` to true.


Skipping duplicates activities
==============================

Use the `:skip_dup_period` option when dispatching an activity to avoid duplicates.

```ruby
  # User is now following Buddy
  activity = FollowBuddyActivity.new(:actor => user, :buddy => followee)

  # skip activity if User already followed Buddy during the last hour
  Activr.dispatch!(activity, :skip_dup_period => 3600)
```

Or you can set that option in global activr configuration>:

```ruby
  Activr.config.skip_dup_period = 3600
```


Trim Timelines
==============

Set `max_length` on a timeline class to specify the maximum number of timeline entries allowed. When a recipient timeline exceed that number then old timeline entries are automatically deleted.


```ruby
class UserNewsFeedTimeline < Activr::Timeline

  recipient User

  max_length 100

  # ...

end
```


Todo
====

- Activities aggregation in timelines
- Rails generator to setup basic views
- Rails generator to setup admin controllers
- Permits "Fanout on read" for inactive entities, to preserve db size
- Permits "Fanout on write with buckets", for maximum read perfs


References
==========

- <http://blog.mongodb.org/post/65612078649/using-mongodb-schema-design-to-create-inboxes>
- <http://www.slideshare.net/danmckinley/etsy-activity-feeds-architecture>


Credits
=======

From Fotonauts:

- Aymerick Jéhanne [@aymerick](https://github.com/aymerick)

Copyright (c) 2013 Fotonauts released under the MIT license.
