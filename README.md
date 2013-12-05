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

Define activity
---------------

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

Entity's class is inferred thanks to entity name, so the `:picture` entity have the `Picture` class, but you can still provide the `:class` option to specify another class.

By convention, the entity that correspond to the user performing the action should be named `:actor`.

The `humanize` method defines a sentence that describes the activity and is a [Mustache](http://mustache.github.io) template. Let's change the generated sentence by a better one:

```ruby
  humanize "{{{actor}}} added picture {{{picture}}} to the album {{{album}}}"
```

The `:humanize` option on entity correspond to a method on corresponding entity's instance that will be used to humanize that entity.

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


Dispatch activity
-----------------

Dispatch that activity in your application when a picture is added to an album:

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

With that controller code:

```ruby
class AlbumsController < ApplicationController

  def create_photo
    @album = Album.find(params[:id])

    # create picture
    picture = Picture.create!(picture_params)

    # add picture to album
    @album.add_picture(picture, current_user)

    flash[:success] = "Photo '#{picture.title}' added to album: '#{@album.name}'"
    redirect_to @album
  end

end
```

Once dispatched the activity is stored in the `activities` MongoDB collection.

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


Global Activity Feed
--------------------

Use `Activr#activities` to fetch the 10 last activities in your app:

```ruby
puts "There are #{Activr.activities_count} activites. Here are the last 10 ones:"

activities = Activr.activities(10)
activities.each do |activity|
  puts activity.humanize
end
```

Note that you can paginate thanks to the `:skip` option of the `#activities` method.


Actor Activity Feed
-------------------

To fetch actor's activity, include the mixin `Activr::Entity::ModelMixin` in your actor's class:

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

Now that class have two new methods: `#activities` and `#activities_count`

Example:

```ruby
user = User.find('john')

puts "#{user.fullname} have #{user.activities_count} activites. Here are the last 10 ones:"

user.activities(10).each do |activity|
  puts activity.humanize
end
```


Album Activity Feed
-------------------

You can too fetch a per-album Activity Feed by including the mixin `Activr::Entity::ModelMixin` in the Album class:

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

puts "#{album.name} have #{album.activities_count} activites. Here are the last 10 ones:"

album.activities(10).each do |activity|
  puts activity.humanize
end
```


Timeline Entries
================

It contains:
- activity
- etc ...
- any metadata you need, for example a 'read' boolean if you want to implemented a read/unread mecanism a user News Feed.


Async
=====


Indexes
=======


Concepts (@todo Move that to blog post)
========

An activity is an event that is (most of the time) performed by a user in your application.

Let's take an example:

`John` `added` `picture 'My face smiling'` to the `album 'My Selfies'`

Given the [Activity Streams](http://activitystrea.ms) specification:

- `John` is the _actor_
- `picture 'My face smiling'` is the _object_
- `album 'My Selfies'` is the _target_
- `added` is the _verb_

But Activr doesn't follow that specification. There is no notion of _object_, _target_ nor _verb_; instead there are _entity_, _activity class_, and by convention the _entity_ that correspond to a user performing an action should be named `:actor`.

So, back to our example, with Activr:

- `John`, `picture 'My face smiling'` and `album 'My Selfies'` are _entities_ that correspond to your application models (probably: `User`, `Picture` and `Album` models).
- This activity correspond to a user adding a picture to album, so it could be named `UserAddsPictureToAlbum`, but well, in our example application only users can add picture to albums, and a picture can only be added to an album, so `AddPicture` is a simpler name.
- `John` is the _entity_ performing the action, so let's call it `:actor`

And we end up with that activity:

```ruby
class AddPictureActivity < Activr::Activity

  entity :actor, :class => User
  entity :picture
  entity :album

end
```


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
