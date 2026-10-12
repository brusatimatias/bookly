module NavigationHelper
  # Sidebar link of the business panel, highlighted when active.
  def admin_nav_link(label, path, icon:, active: false, **options)
    classes = "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
    classes += active ? " bg-brand-50 text-brand-700" : " text-gray-700 hover:bg-gray-50 hover:text-gray-900"

    link_to path, class: classes, "aria-current": (active ? "page" : nil), **options do
      icon(icon, class: active ? "text-brand-600" : "text-gray-400") + label
    end
  end
end
