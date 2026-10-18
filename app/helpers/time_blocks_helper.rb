module TimeBlocksHelper
  # "lun 20 oct – vie 24 oct" for whole days, like format_period otherwise.
  def time_block_period(time_block)
    if time_block.whole_days?
      [ time_block.starts_at.to_date, time_block.last_day ].uniq.map { |date| l(date, format: :weekday) }.join(" – ")
    else
      format_period(time_block.starts_at, time_block.ends_at)
    end
  end
end
