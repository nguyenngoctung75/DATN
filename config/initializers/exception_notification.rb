# frozen_string_literal: true

# Only load in environments where we want to send error alerts.
return unless %w[development staging].include?(Rails.env)
return unless ActiveModel::Type::Boolean.new.cast(ENV.fetch("ERROR_NOTIFICATION_ENABLED", "false"))

require "exception_notification/rails"

ExceptionNotification.configure do |config|
  # ----- Ignored exceptions (404 family + abort responses) -----
  config.ignored_exceptions += %w[
    ActionController::RoutingError
    ActiveRecord::RecordNotFound
    ActionController::UnknownFormat
    ActionController::BadRequest
    ActionController::ParameterMissing
    ActionController::InvalidAuthenticityToken
    AbstractController::ActionNotFound
  ]

  # ----- Skip known bots / crawlers (User-Agent) -----
  config.ignore_crawlers %w[
    Googlebot Bingbot Slurp DuckDuckBot Baiduspider YandexBot
    Sogou Exabot facebot facebookexternalhit ia_archiver
    AhrefsBot SemrushBot MJ12bot DotBot PetalBot Bytespider
    GPTBot ClaudeBot CCBot Applebot
    curl wget HeadlessChrome PhantomJS Selenium HTTPie python-requests
    UptimeRobot Pingdom StatusCake
  ]

  # ----- Extra ignore: any UA matching bot/crawler/spider keyword -----
  config.ignore_if do |_exception, options|
    env = options[:env]
    next false unless env

    ua = env["HTTP_USER_AGENT"].to_s
    ua.match?(/bot|crawler|spider|scraper/i) && !ua.match?(/Mozilla/)
  end

  # ----- Throttle: same exception (class + normalized message) -----
  # Dev uses memory_store (resets on restart). Staging uses solid_cache_store (MySQL-backed, persisted).
  config.error_grouping        = true
  config.error_grouping_cache  = Rails.cache
  config.error_grouping_period = ENV.fetch("ERROR_NOTIFICATION_THROTTLE_MINUTES", "10").to_i.minutes

  # Alert at count 1, then at 10, 100, 500, 1000, 2000, ... to avoid spam.
  config.notification_trigger = ->(_exception, count) {
    count == 1 || count == 10 || count == 100 || count == 500 || (count % 1000).zero?
  }

  # ----- Email notifier -----
  config.add_notifier :email, {
    email_prefix:         ENV.fetch("ERROR_NOTIFICATION_PREFIX", "[tool_test]") + " ",
    sender_address:       %("Error Tracker" <#{ENV.fetch("ERROR_NOTIFICATION_SENDER")}>),
    exception_recipients: ENV.fetch("ERROR_NOTIFICATION_RECIPIENTS").split(",").map(&:strip),
    email_format:         :text,
    sections:             %w[request session environment backtrace],
    background_sections:  %w[backtrace data],
    deliver_with:         :deliver_now  # deliver_later would loop if the mailer job itself fails
  }
end
