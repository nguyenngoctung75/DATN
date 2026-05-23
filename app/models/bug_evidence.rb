class BugEvidence < ApplicationRecord
  belongs_to :bug

  validates :bug_id, presence: true
  validates :content_type, presence: true
  validates :content_value, presence: true

  scope :by_type, ->(type) { where(content_type: type) }
end
