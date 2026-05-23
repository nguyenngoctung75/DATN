class DeviceClassifier
  PATTERNS = {
    'pc'  => { match: /chrome|firefox|safari|edge|prod|stg|pc/, exclude: /android|ios|iphone|ipad/ },
    'sp'  => { match: /android|ios|iphone|ipad|testflight|deploy.*gate|sp/, exclude: nil },
    'app' => { match: /app|(android|ios|iphone|ipad).*\d+\.\d+\.\d+/, exclude: nil }
  }.freeze

  def self.match?(device_name, category)
    return false if device_name.blank?

    name = device_name.downcase
    pattern = PATTERNS[category.to_s.downcase]
    return name == category.to_s.downcase unless pattern

    name.match?(pattern[:match]) &&
      (pattern[:exclude].nil? || !name.match?(pattern[:exclude]))
  end
end
