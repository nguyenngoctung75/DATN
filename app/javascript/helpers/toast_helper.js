/**
 * Show a toast notification
 * @param {string} message - The message to display
 * @param {string} type - The type of toast (success, error, warning, info)
 * @param {number} delay - Auto-hide delay in milliseconds (default: 5000)
 * @param {object} options - Optional: { link: url } to make toast clickable and redirect
 */
export function showToast(message, type = 'info', delay = 5000, options = {}) {
  // Check if Bootstrap is loaded
  if (typeof bootstrap === 'undefined' || !bootstrap.Toast) {
    console.error('Bootstrap Toast is not available')
    return null
  }

  // Get or create toast container
  let container = document.querySelector('.toast-container')
  if (!container) {
    container = document.createElement('div')
    container.className = 'toast-container position-fixed top-0 end-0 p-3'
    container.style.zIndex = '9999'
    document.body.appendChild(container)
  }

  // Define colors and icons based on type
  const typeConfig = {
    success: {
      bgClass: 'bg-success text-white',
      icon: 'bi-check-circle-fill',
      closeClass: 'btn-close-white'
    },
    error: {
      bgClass: 'bg-danger text-white',
      icon: 'bi-x-circle-fill',
      closeClass: 'btn-close-white'
    },
    warning: {
      bgClass: 'bg-warning text-dark',
      icon: 'bi-exclamation-triangle-fill',
      closeClass: ''
    },
    info: {
      bgClass: 'bg-info text-white',
      icon: 'bi-info-circle-fill',
      closeClass: 'btn-close-white'
    },
    secondary: {
      bgClass: 'bg-secondary text-white',
      icon: 'bi-bell-fill',
      closeClass: 'btn-close-white'
    }
  }

  const config = typeConfig[type] || typeConfig.info

  // Use DOM API and textContent for message to prevent XSS (no innerHTML for user content)
  const toastEl = document.createElement('div')
  toastEl.className = `toast align-items-center border-0 shadow-lg ${config.bgClass}`
  toastEl.setAttribute('role', 'alert')
  toastEl.setAttribute('aria-live', 'assertive')
  toastEl.setAttribute('aria-atomic', 'true')

  if (options.link) {
    toastEl.style.cursor = 'pointer'
  }

  const div = document.createElement('div')
  div.className = 'd-flex'
  const body = document.createElement('div')
  body.className = 'toast-body d-flex align-items-center flex-grow-1'
  const icon = document.createElement('i')
  icon.className = `bi ${config.icon} fs-5 me-2`
  const span = document.createElement('span')
  span.textContent = message == null ? '' : String(message)
  const btn = document.createElement('button')
  btn.type = 'button'
  btn.className = `btn-close me-2 m-auto ${config.closeClass}`
  btn.setAttribute('data-bs-dismiss', 'toast')
  btn.setAttribute('aria-label', 'Close')
  body.appendChild(icon)
  body.appendChild(span)
  div.appendChild(body)
  div.appendChild(btn)
  toastEl.appendChild(div)

  if (options.link) {
    toastEl.addEventListener('click', function (e) {
      if (!e.target.closest('.btn-close')) {
        window.location.href = options.link
      }
    })
  }

  // Add to container
  container.appendChild(toastEl)

  // Initialize and show toast (using global bootstrap object from CDN)
  const toast = new bootstrap.Toast(toastEl, {
    autohide: true,
    delay: delay
  })

  toast.show()

  // Remove element after hidden
  toastEl.addEventListener('hidden.bs.toast', () => {
    toastEl.remove()
  })

  return toast
}

/**
 * Convenience methods
 */
export const toastSuccess = (message, delay) => showToast(message, 'success', delay)
export const toastError = (message, delay) => showToast(message, 'error', delay)
export const toastWarning = (message, delay) => showToast(message, 'warning', delay)
export const toastInfo = (message, delay) => showToast(message, 'info', delay)

// Make it available globally if needed
window.showToast = showToast
window.toastSuccess = toastSuccess
window.toastError = toastError
window.toastWarning = toastWarning
window.toastInfo = toastInfo

