require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:notification)).to be_valid
    end

    it 'requires title' do
      expect(build(:notification, title: nil)).not_to be_valid
    end

    it 'requires valid category' do
      expect(build(:notification, category: 'invalid')).not_to be_valid
    end

    it 'accepts all valid categories' do
      Notification::CATEGORIES.each do |cat|
        expect(build(:notification, category: cat)).to be_valid
      end
    end
  end

  describe '.visible_for' do
    let(:admin) { create(:user, :admin) }
    let(:regular_user) { create(:user) }
    let!(:info_notif) { create(:notification, category: 'info') }
    let!(:cron_notif) { create(:notification, category: 'cronjob') }

    it 'shows all notifications to admins' do
      expect(Notification.visible_for(admin)).to include(info_notif, cron_notif)
    end

    it 'hides cronjob notifications from regular users' do
      visible = Notification.visible_for(regular_user)
      expect(visible).to include(info_notif)
      expect(visible).not_to include(cron_notif)
    end
  end

  describe '.unread_for' do
    let(:user) { create(:user) }
    let!(:notif) { create(:notification) }

    it 'returns notifications not yet read by user' do
      expect(Notification.unread_for(user)).to include(notif)
    end

    it 'excludes notifications already read by user' do
      NotificationRead.create!(user: user, notification: notif, read_at: Time.current)
      expect(Notification.unread_for(user)).not_to include(notif)
    end
  end
end
