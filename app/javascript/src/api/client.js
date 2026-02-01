const getToken = () => localStorage.getItem('auth_token')

const handleResponse = async (response) => {
  if (response.status === 401) {
    localStorage.removeItem('auth_token')
    localStorage.removeItem('current_user')
    window.location.href = '/login'
    return null
  }

  // CSV downloads
  const contentType = response.headers.get('content-type') || ''
  if (contentType.includes('text/csv')) {
    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = response.headers.get('content-disposition')?.match(/filename="(.+)"/)?.[1] || 'export.csv'
    a.click()
    URL.revokeObjectURL(url)
    return { downloaded: true }
  }

  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    throw new Error(body.error || body.errors?.join(', ') || `HTTP ${response.status}`)
  }

  return response.json()
}

const request = async (url, options = {}) => {
  const headers = {
    'Authorization': `Bearer ${getToken()}`,
    'Accept': 'application/json',
    ...options.headers
  }

  try {
    const response = await fetch(url, { ...options, headers })
    return await handleResponse(response)
  } catch (error) {
    console.error(`API error [${options.method || 'GET'} ${url}]:`, error.message)
    throw error
  }
}

export const apiClient = {
  get: (url) => request(url),

  post: (url, body) => request(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }),

  put: (url, body) => request(url, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }),

  delete: (url) => request(url, { method: 'DELETE' }),

  // File upload (for future receipt snap etc)
  upload: (url, formData) => request(url, {
    method: 'POST',
    body: formData
    // No Content-Type header — browser sets multipart boundary
  })
}
