class TestStepContent < ApplicationRecord
  include Loggable

  belongs_to :test_step, foreign_key: 'step_id', inverse_of: :test_step_contents

  validates :content_type, presence: true
  validates :content_value, presence: true
  validates :content_category, presence: true

  before_validation :unescape_content_value

  scope :actions, -> { where(content_category: 'action') }
  scope :expectations, -> { where(content_category: 'expectation') }
  scope :by_type, ->(type) { where(content_type: type) }
  scope :ordered, -> { order(:display_order) }

  private

  def unescape_content_value
    return unless content_value.present? && content_type == 'text'

    self.content_value = CGI.unescapeHTML(content_value.to_s)
  end
end
