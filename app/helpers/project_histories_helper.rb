module ProjectHistoriesHelper
  def action_badge_class(action)
    case action
    when 'create'
      'bg-success text-white'
    when 'update'
      'bg-info text-white'
    when 'delete'
      'bg-warning text-dark'
    when 'restore'
      'bg-primary text-white'
    when 'destroy'
      'bg-danger text-white'
    else
      'bg-secondary text-white'
    end
  end

  def text_class_for_action(action)
    case action
    when 'create'
      'text-success'
    when 'update'
      'text-info'
    when 'delete'
      'text-warning'
    when 'restore'
      'text-primary'
    when 'destroy'
      'text-danger'
    else
      'text-secondary'
    end
  end
end
