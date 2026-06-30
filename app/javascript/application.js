import "@hotwired/turbo-rails"
import "controllers"
import "helpers/toast_helper"

Turbo.config.forms.confirm = (message, element) => {
  return confirm(message)
}
