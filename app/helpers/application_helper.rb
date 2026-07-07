module ApplicationHelper
  def nav_link_class(active)
    base = "text-sm font-medium "
    base + (active ? "text-emerald-700" : "text-gray-600 hover:text-gray-900")
  end
end
