const baseUrl = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '');
export async function api(path, options = {}) {
  const token = sessionStorage.getItem('signfix_token');
  const controller = new AbortController();
  const timeoutMs = Number(options.timeoutMs || 15000);
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const { timeoutMs: _timeoutMs, signal: callerSignal, ...fetchOptions } = options;
  if (callerSignal) {
    if (callerSignal.aborted) controller.abort();
    else callerSignal.addEventListener('abort', () => controller.abort(), { once: true });
  }
  try {
    const response = await fetch(`${baseUrl}${path}`, { ...fetchOptions, signal: controller.signal, headers: { ...(fetchOptions.body && !(fetchOptions.body instanceof FormData) ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...fetchOptions.headers } });
    const body = response.status === 204 ? null : await response.json().catch(() => ({}));
    if (!response.ok) throw Object.assign(new Error(body?.error || 'Request failed'), { status: response.status, details: body?.details });
    return body;
  } catch (error) {
    if (error?.name === 'AbortError') throw Object.assign(new Error('The server took too long to respond. Please try again.'), { status: 408, code: 'CLIENT_TIMEOUT' });
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}
export const get = (path) => api(path);
export const post = (path, data) => api(path, { method: 'POST', body: JSON.stringify(data) });
export const patch = (path, data) => api(path, { method: 'PATCH', body: JSON.stringify(data) });
export const remove = (path) => api(path, { method: 'DELETE' });
