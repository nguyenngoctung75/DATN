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

  TEST_PHASE_BADGE = {
    'not_started'        => 'bg-secondary',
    'creating_testcases' => 'bg-info',
    'executing'          => 'bg-primary',
    'reporting'          => 'bg-warning text-dark',
    'completed'          => 'bg-success'
  }.freeze

  def task_status_bg_class(status)
    TASK_STATUS_BG[status.to_s.downcase] || 'bg-light text-dark'
  end

  def task_status_text_class(status)
    TASK_STATUS_TEXT[status.to_s.downcase] || 'text-dark'
  end

  def test_phase_badge_class(phase)
    TEST_PHASE_BADGE[phase.to_s] || 'bg-secondary'
  end
end
