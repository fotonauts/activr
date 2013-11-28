class AddPhoto < Activr::Activity

  entity :actor, :class => User,    :humanize => :fullname
  entity :photo, :class => Picture, :humanize => :title
  entity :album, :class => Album,   :humanize => :name

  humanize "{{actor}} added photo {{photo}} to the {{album}} album"

end
