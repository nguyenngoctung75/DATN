module DateHelper
  def format_date(date, format = '%Y-%m-%d')
    date&.strftime(format)
  end

  def time_ago(datetime)
    return '-' if datetime.nil?

    time_ago_in_words(datetime)
  end
end
