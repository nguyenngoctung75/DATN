export async function csrfFetch(url, options = {}) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  return fetch(url, {
    ...options,
    headers: {
      ...(options.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
      "X-CSRF-Token": csrfToken,
      "Accept": "application/json",
      ...(options.headers || {})
    }
  })
}
