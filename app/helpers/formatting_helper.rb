module FormattingHelper
  # Symbol shown for each currency; any other code is shown as is ("CLP 1.500").
  CURRENCY_UNITS = { "ARS" => "$", "USD" => "$", "EUR" => "€" }.freeze

  # 1_200_000 -> "$ 12.000" (es) / "$12,000" (en). Decimals only when there are cents.
  def format_price(cents, currency: Current.business.currency)
    unit = CURRENCY_UNITS[currency]
    options = unit ? { unit: unit } : { unit: currency, format: "%u %n" }

    number_to_currency(cents / 100r, precision: (cents % 100).zero? ? 0 : 2, **options)
  end

  # 90 -> "1 h 30 min"
  def format_duration(minutes)
    hours, minutes = minutes.divmod(60)
    parts = []
    parts << t("formatting.duration.hours", count: hours) if hours.positive?
    parts << t("formatting.duration.minutes", count: minutes) if minutes.positive? || hours.zero?
    parts.join(" ")
  end

  # "America/Argentina/Buenos_Aires" -> "Buenos Aires": the friendly Rails name
  # when there is one, the identifier otherwise.
  def time_zone_label(zone = Current.business.time_zone)
    ActiveSupport::TimeZone::MAPPING.key(zone) || zone
  end

  # "jue 15 oct, 16:00 – 19:00" within a day, "jue 15 oct 22:00 – vie 16 oct
  # 08:00" across days.
  def format_period(starts_at, ends_at)
    if starts_at.to_date == ends_at.to_date
      "#{l(starts_at.to_date, format: :weekday)}, #{l(starts_at, format: :hour)} – #{l(ends_at, format: :hour)}"
    else
      [ starts_at, ends_at ].map { |time| "#{l(time.to_date, format: :weekday)} #{l(time, format: :hour)}" }.join(" – ")
    end
  end
end
