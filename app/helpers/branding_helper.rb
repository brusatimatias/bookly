# A business's brand on the pages its customers see. Its color replaces the
# theme's brand-* scale, which Tailwind's utilities read from CSS variables:
# brand-600 (buttons) is the color itself, lighter and darker shades are mixed
# with white or black. The panel keeps Bookly's.
module BrandingHelper
  SHADES = {
    50 => "white 92%", 100 => "white 84%", 200 => "white 68%", 300 => "white 50%", 400 => "white 30%",
    500 => "white 14%", 700 => "black 16%", 800 => "black 32%", 900 => "black 46%"
  }.freeze

  # The business whose brand the page wears: the current one, while it's
  # active (a suspended business's page shows nothing of it).
  def branded_business
    Current.business if Current.business&.active?
  end

  def brand_style_tag(business)
    color = business&.brand_color
    return unless color&.match?(BrandColor::FORMAT)

    variables = SHADES.map { |shade, mix| "--color-brand-#{shade}: color-mix(in oklab, #{color}, #{mix});" }
    # The color is validated as #rrggbb (and by a check constraint), so it's safe in CSS.
    tag.style(":root { --color-brand-600: #{color}; #{variables.join(" ")} }".html_safe)
  end
end
