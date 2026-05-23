class DeviceListBuilder
  def initialize(task)
    @task = task
  end

  def build
    config = effective_config
    return config.split(',').map(&:strip).reject(&:blank?) if config.present?

    devices = TestResult.active.joins(:test_case)
                        .where(test_cases: { task_id: @task.id })
                        .pluck(:device).uniq.compact
    devices.any? ? prod_last_sort(devices) : []
  end

  private

  def effective_config
    return @task.device_config if @task.device_config.present?
    return @task.parent.device_config if @task.parent_id.present? && @task.parent&.device_config.present?

    nil
  end

  def prod_last_sort(devices)
    devices.sort do |a, b|
      a_prod = a.to_s.downcase.match?(/^prod(uction)?$/)
      b_prod = b.to_s.downcase.match?(/^prod(uction)?$/)
      if a_prod && !b_prod then 1
      elsif !a_prod && b_prod then -1
      else a.to_s.downcase <=> b.to_s.downcase
      end
    end
  end
end
