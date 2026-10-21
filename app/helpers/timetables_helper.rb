module TimetablesHelper
  def next_weekday_date(weekday, from: Date.current)
    date = from.to_date
    date += 1 while date.cwday != weekday.to_i
    date
  end

  def weekday_in_week(weekday, week_start)
    week_start.to_date + (weekday.to_i - 1)
  end
end
