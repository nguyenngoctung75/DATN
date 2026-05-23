module ImportRunsHelper
  def status_badge_class(status)
    case status.to_s
    when 'success' then 'bg-success'
    when 'failed' then 'bg-danger'
    when 'running' then 'bg-info text-dark'
    else 'bg-secondary'
    end
  end
end
