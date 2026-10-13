module TimeBlocksHelper
  # "lun 20 oct – vie 24 oct" for whole days, "jue 15 oct, 16:00 – 19:00" within
  # a day, "jue 15 oct 22:00 – vie 16 oct 08:00" otherwise.
  def time_block_period(time_block)
    starts_at, ends_at = time_block.starts_at, time_block.ends_at

    if time_block.whole_days?
      [ starts_at.to_date, time_block.last_day ].uniq.map { |date| l(date, format: :weekday) }.join(" – ")
    elsif starts_at.to_date == ends_at.to_date
      "#{l(starts_at.to_date, format: :weekday)}, #{l(starts_at, format: :hour)} – #{l(ends_at, format: :hour)}"
    else
      [ starts_at, ends_at ].map { |time| "#{l(time.to_date, format: :weekday)} #{l(time, format: :hour)}" }.join(" – ")
    end
  end
end
