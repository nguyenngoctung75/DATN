class AppConfiguration < ApplicationRecord
  validate :single_record, on: :create

  def self.instance
    first_or_create!
  end

  private

  def single_record
    errors.add(:base, 'There can only be one AppConfiguration') if AppConfiguration.exists?
  end
end
