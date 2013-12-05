class AddPicture < Activr::Activity

  entity :actor,   :class => User,    :humanize => :fullname
  entity :picture, :class => Picture, :humanize => :title
  entity :album,   :class => Album,   :humanize => :name

  humanize "{{{actor}}} added picture {{{picture}}} to the {{{album}}} album"

end
