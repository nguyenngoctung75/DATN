// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "helpers/toast_helper"

// Turbo confirm handler - uses native browser confirm dialog (new API)
Turbo.config.forms.confirm = (message, element) => {
  return confirm(message)
}
