class TestStep < ApplicationRecord
  include Loggable

  belongs_to :test_case, foreign_key: 'case_id', inverse_of: :test_steps
  has_many :test_step_contents, foreign_key: 'step_id', dependent: :destroy, inverse_of: :test_step

  # Nested attributes for creating step contents - reject blank contents
  accepts_nested_attributes_for :test_step_contents, allow_destroy: true, reject_if: lambda { |attrs|
    attrs[:content_value].blank?
  }

  validates :step_number, presence: true, numericality: { greater_than: 0 }

  # Auto-renumber siblings after destroy
  after_destroy :renumber_sibling_steps

  scope :ordered, -> { order(:step_number) }
  scope :active, -> { where(deleted_at: nil) }

  # Add scopes to get contents by category
  def action_contents
    test_step_contents.where(content_category: 'action').order(:display_order)
  end

  def expected_contents
    test_step_contents.where(content_category: 'expectation').order(:display_order)
  end

  def content_count
    test_step_contents.count
  end

  def actions?
    action_contents.exists?
  end

  def expectations?
    expected_contents.exists?
  end

  # Create summary of step
  def action_summary
    actions = action_contents.pluck(:content_value).join(', ')
    actions.presence || 'No action defined'
  end

  def expected_summary
    expectations = expected_contents.pluck(:content_value).join(', ')
    expectations.presence || 'No expectation defined'
  end

  # Full summary
  def summary
    "Step #{step_number}: #{action_summary} → Expected: #{expected_summary}"
  end

  private

  # Renumber remaining steps in the same test case after deletion
  def renumber_sibling_steps
    return unless test_case

    test_case.test_steps.ordered.each_with_index do |step, index|
      new_number = index + 1
      step.update_column(:step_number, new_number) if step.step_number != new_number
    end
  end
end
