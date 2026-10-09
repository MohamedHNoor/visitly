module ApplicationHelper
  # Stroke icon paths from the visitly-design prototype (24x24 viewBox).
  ICON_PATHS = {
    calendar: "M4 5h16v16H4zM8 3v4M16 3v4M4 10h16",
    car: "M5 8l2-5h10l2 5M3 8h18v10H3zM5 18v3M19 18v3M6 12h2M16 12h2",
    check: "M5 12l4 4L19 6",
    close: "M6 6l12 12M6 18L18 6",
    home: "M3 10l9-7 9 7M5 9v12h14V9M9 21v-8h6v8",
    mail: "M3 5h18v14H3zM3 5l9 7 9-7",
    menu: "M4 6h16M4 12h16M4 18h16",
    money: "M3 5h18v14H3zM12 8a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
    pin: "M12 21s7-6 7-12a7 7 0 1 0-14 0c0 6 7 12 7 12M12 6a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
    repeat: "M3 7h15l-3-3M21 17H6l3 3M21 7v5M3 17v-5",
    users: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M18 8a3 3 0 0 1 0 6"
  }.freeze

  def icon(name, css_class: nil)
    tag.svg(class: [ "icon", css_class ], viewBox: "0 0 24 24", aria: { hidden: true }, focusable: false) do
      tag.path(d: ICON_PATHS.fetch(name))
    end
  end
end
