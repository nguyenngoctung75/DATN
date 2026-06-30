class ApplicationJob < ActiveJob::Base
  retry_on Net::OpenTimeout, attempts: 3, wait: :polynomially_longer
  retry_on ActiveRecord::Deadlocked, attempts: 3, wait: :polynomially_longer
  discard_on ActiveJob::DeserializationError

  rescue_from(StandardError) do |exception|
    notify_exception_tracker(exception)
    raise exception
  end

  private

  def notify_exception_tracker(exception)
    return unless defined?(ExceptionNotifier)
    return unless ActiveModel::Type::Boolean.new.cast(ENV.fetch('ERROR_NOTIFICATION_ENABLED', 'false'))

    ExceptionNotifier.notify_exception(
      exception,
      data: {
        job_class:  self.class.name,
        job_id:     job_id,
        queue:      queue_name,
        arguments:  arguments,
        executions: executions
      }
    )
  rescue => notifier_error
    Rails.logger.error("[ExceptionNotifier] failed to notify: #{notifier_error.class}: #{notifier_error.message}")
  end
end
