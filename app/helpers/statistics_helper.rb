module StatisticsHelper
  # From no appointments to the busiest hour. Listed in full so Tailwind keeps them.
  PEAK_HOUR_SHADES = %w[bg-gray-50 bg-brand-100 bg-brand-200 bg-brand-400 bg-brand-600 bg-brand-800].freeze

  # 0.25 -> "25 %" (es) / "25%" (en); "—" when there's nothing to compare.
  def format_rate(rate)
    rate ? number_to_percentage(rate * 100, precision: 0) : "—"
  end

  # The cell of an hour in the peak hours grid, darker the busier it is.
  def peak_hour_cell_class(count, busiest)
    shade = count.zero? ? 0 : (count * (PEAK_HOUR_SHADES.size - 1)).fdiv(busiest).ceil
    [ PEAK_HOUR_SHADES[shade], ("text-white" if shade >= 4) ].compact.join(" ")
  end

  # The days of the week, Monday first, as Date#wday.
  def weekdays_from_monday
    [ 1, 2, 3, 4, 5, 6, 0 ]
  end
end
