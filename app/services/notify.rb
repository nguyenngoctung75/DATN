class Notify
  def self.info(title:, message:, link: nil)
    Notification.create!(category: 'info', title: title, message: message, link: link)
  end

  def self.warning(title:, message:, link: nil)
    Notification.create!(category: 'warning', title: title, message: message, link: link)
  end

  def self.cronjob(title:, message:, link: nil)
    Notification.create!(category: 'cronjob', title: title, message: message, link: link)
  end
end
