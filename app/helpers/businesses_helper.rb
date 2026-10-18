module BusinessesHelper
  # [["(GMT-03:00) Buenos Aires", "America/Argentina/Buenos_Aires"], ...]: the
  # Rails zones by offset, one per identifier (businesses store identifiers).
  # A selected identifier without a Rails name is kept as is.
  def time_zone_options(selected = nil)
    options = ActiveSupport::TimeZone.all.uniq { |zone| zone.tzinfo.name }.map { |zone| [ zone.to_s, zone.tzinfo.name ] }
    options << [ selected, selected ] if selected.present? && options.none? { |_, identifier| identifier == selected }
    options
  end

  # Each language named in itself.
  def locale_options
    I18n.available_locales.map { |locale| [ t("locale_names.#{locale}"), locale.to_s ] }
  end

  # [["ARS — Peso argentino", "ARS"], ...]
  def currency_options
    Business::CURRENCIES.map { |code| [ "#{code} — #{t("currencies.#{code}")}", code ] }
  end
end
