class DateRangePreset
  DATE_PRESETS = {
    'today' => -> { Date.current..Date.current },
    'yesterday' => -> { Date.yesterday..Date.yesterday },
    'last_7_days' => -> { 6.days.ago.to_date..Date.current },
    'last_30_days' => -> { 29.days.ago.to_date..Date.current },
    'this_week' => -> { Date.current.beginning_of_week..Date.current },
    'last_week' => -> { 1.week.ago.beginning_of_week.to_date..1.week.ago.end_of_week.to_date },
    'this_month' => -> { Date.current.beginning_of_month..Date.current },
    'last_month' => -> { 1.month.ago.beginning_of_month.to_date..1.month.ago.end_of_month.to_date },
    'this_quarter' => -> { Date.current.beginning_of_quarter..Date.current },
    'last_quarter' => -> { 1.quarter.ago.beginning_of_quarter.to_date..1.quarter.ago.end_of_quarter.to_date },
    'this_year' => -> { Date.current.beginning_of_year..Date.current },
    'last_year' => -> { 1.year.ago.beginning_of_year.to_date..1.year.ago.end_of_year.to_date }
  }.freeze

  def self.key?(key)
    DATE_PRESETS.key?(key.to_s)
  end

  def self.resolve(key)
    DATE_PRESETS[key.to_s]&.call
  end
end
