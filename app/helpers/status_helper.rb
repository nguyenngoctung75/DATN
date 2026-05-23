module StatusHelper
  TASK_STATUS_BG = {
    'new'             => 'bg-info',
    'pending'         => 'bg-warning text-dark',
    'in progress'     => 'bg-primary',
    'resolved'        => 'bg-success',
    'waiting release' => 'bg-purple',
    'closed'          => 'bg-secondary'
  }.freeze

  TASK_STATUS_TEXT = {
    'new'             => 'text-info',
    'pending'         => 'text-warning',
    'in progress'     => 'text-primary',
    'resolved'        => 'text-success',
    'waiting release' => 'text-purple',
    'closed'          => 'text-secondary'
  }.freeze

  def task_status_bg_class(status)
    TASK_STATUS_BG[status.to_s.downcase] || 'bg-light text-dark'
  end

  def task_status_text_class(status)
    TASK_STATUS_TEXT[status.to_s.downcase] || 'text-dark'
  end
end
