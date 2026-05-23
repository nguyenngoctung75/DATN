require 'rails_helper'

RSpec.describe Notify do
  describe '.info' do
    it 'creates a Notification with category info' do
      expect { described_class.info(title: 'Done', message: 'All good') }
        .to change(Notification, :count).by(1)
      notif = Notification.order(:id).last
      expect(notif.category).to eq('info')
      expect(notif.title).to eq('Done')
      expect(notif.message).to eq('All good')
      expect(notif.link).to be_nil
    end

    it 'stores link when provided' do
      described_class.info(title: 'Done', message: 'ok', link: '/import_runs/1')
      expect(Notification.order(:id).last.link).to eq('/import_runs/1')
    end
  end

  describe '.warning' do
    it 'creates a Notification with category warning' do
      expect { described_class.warning(title: 'Alert', message: 'Something failed') }
        .to change(Notification, :count).by(1)
      expect(Notification.order(:id).last.category).to eq('warning')
    end
  end

  describe '.cronjob' do
    it 'creates a Notification with category cronjob' do
      expect { described_class.cronjob(title: 'Cron', message: 'Ran ok') }
        .to change(Notification, :count).by(1)
      expect(Notification.order(:id).last.category).to eq('cronjob')
    end
  end
end
