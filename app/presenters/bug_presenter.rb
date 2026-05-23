class BugPresenter < SimpleDelegator
  PRIORITY_COLORS = {
    'urgent' => 'danger', 'high' => 'danger', 'normal' => 'warning', 'low' => 'info'
  }.freeze

  STATUS_COLORS = {
    'new' => 'primary', 'fixing' => 'warning', 'testing' => 'info',
    'pending' => 'secondary', 'done' => 'success'
  }.freeze

  CATEGORY_LABELS = {
    'stg_vn' => 'STG Bugs (VN)', 'stg_jp' => 'STG Bugs (JP)',
    'new_requirement' => 'New Requirement', 'prod' => 'Prod Bugs'
  }.freeze

  BUG_TYPE_LABELS  = { 'new_bug' => 'New Bug', 'old_bug' => 'Old Bug', 'improve' => 'Improve' }.freeze
  BUG_TYPE_COLORS  = { 'new_bug' => 'danger', 'old_bug' => 'warning', 'improve' => 'info' }.freeze
  APPLICATION_LABELS = {
    'sp_pc' => 'SP + PC', 'app' => 'APP', 'sp' => 'SP', 'pc' => 'PC', 'all' => 'SP + PC + APP'
  }.freeze

  def priority_color      = PRIORITY_COLORS[priority]    || 'secondary'
  def status_color        = STATUS_COLORS[status]        || 'secondary'
  def category_display    = CATEGORY_LABELS[category]    || category.to_s.humanize
  def bug_type_display    = BUG_TYPE_LABELS[bug_type]    || bug_type.to_s.humanize
  def bug_type_color      = BUG_TYPE_COLORS[bug_type]    || 'secondary'
  def application_display = APPLICATION_LABELS[application] || application.to_s.humanize

  def dev_name    = dev&.name    || dev_name_raw    || 'N/A'
  def tester_name = tester&.name || tester_name_raw || 'N/A'
end
