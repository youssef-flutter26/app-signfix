const crypto = require('crypto');

// Delhivery One MCP gateway client. The gateway speaks JSON-RPC over HTTPS
// (see the d1-mcp-mint proxy this replicates): a short-lived bearer token is
// minted with an OAuth2 client_credentials grant, then every tool call is a
// POST of {"jsonrpc":"2.0","method":"tools/call",...} with the token plus the
// HQ client id in headers. Responses arrive as SSE `data:` lines.
//
// Only the global fetch API is used; there are no new dependencies.
const TOKEN_REFRESH_SKEW_SECONDS = 30;
const MAX_MINT_RETRIES = 3;
const TOOLS_CACHE_TTL_MS = 5 * 60 * 1000;

function config() {
  return {
    clientId: process.env.D1_CLIENT_ID || '',
    clientSecret: process.env.D1_CLIENT_SECRET || '',
    authUrl: (process.env.D1_AUTH_URL || '').replace(/\/$/, ''),
    realm: process.env.D1_REALM || '',
    clientCms: process.env.D1_CLIENT_CMS || '',
    mcpUrl: (process.env.D1_MCP_URL || '').replace(/\/$/, ''),
    timeoutMs: Number(process.env.D1_TIMEOUT_MS || 15000),
  };
}

function isEnabled() {
  const { clientId, clientSecret, authUrl, realm, clientCms, mcpUrl } = config();
  return Boolean(clientId && clientSecret && authUrl && realm && clientCms && mcpUrl);
}

function tokenUrl() {
  const { authUrl, realm } = config();
  return `${authUrl}/realms/${realm}/protocol/openid-connect/token`;
}

// In-memory token cache. Tokens live ~10 minutes, so a single process-wide
// entry is enough; concurrent callers share one in-flight mint.
let cachedToken = null;
let expiresAt = 0;
let mintPromise = null;
let cachedTools = null;
let toolsFetchedAt = 0;

async function mintToken() {
  const { clientId, clientSecret, timeoutMs } = config();
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: clientId,
    client_secret: clientSecret,
  });
  let lastError = null;
  for (let attempt = 0; attempt < MAX_MINT_RETRIES; attempt += 1) {
    try {
      const response = await fetch(tokenUrl(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Request-ID': crypto.randomUUID(),
        },
        body: body.toString(),
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (response.status === 401 || response.status === 403) {
        throw Object.assign(new Error('Delhivery One rejected the client credentials'), { status: 502, errorCode: 'D1_AUTH_FAILED' });
      }
      if (!response.ok) {
        throw Object.assign(new Error(`Delhivery One auth failed with HTTP ${response.status}`), { status: 502, errorCode: 'D1_AUTH_FAILED' });
      }
      const data = await response.json().catch(() => ({}));
      if (!data.access_token) throw Object.assign(new Error('Delhivery One auth returned no access token'), { status: 502, errorCode: 'D1_AUTH_FAILED' });
      cachedToken = data.access_token;
      expiresAt = Date.now() + Number(data.expires_in || 300) * 1000;
      return cachedToken;
    } catch (error) {
      if (error && (error.errorCode === 'D1_AUTH_FAILED' || error.status === 502)) throw error;
      lastError = error;
      if (attempt < MAX_MINT_RETRIES - 1) {
        await new Promise((resolve) => setTimeout(resolve, 2 ** attempt * 1000 + Math.random() * 500));
      }
    }
  }
  if (lastError && (lastError.name === 'TimeoutError' || lastError.name === 'AbortError')) {
    throw Object.assign(new Error('Delhivery One auth timed out'), { status: 502, errorCode: 'D1_UNREACHABLE', cause: lastError });
  }
  throw Object.assign(new Error('Delhivery One auth service is unreachable'), { status: 502, errorCode: 'D1_UNREACHABLE', cause: lastError });
}

async function getToken() {
  // Refresh 30 seconds before actual expiry so a slow tool call never races
  // the token deadline.
  if (cachedToken && Date.now() < expiresAt - TOKEN_REFRESH_SKEW_SECONDS * 1000) return cachedToken;
  if (!mintPromise) mintPromise = mintToken().finally(() => { mintPromise = null; });
  return mintPromise;
}

function errorMessage(status, fallback) {
  return status === 401 || status === 403
    ? 'Delhivery One rejected the request (auth)'
    : `${fallback} (HTTP ${status})`;
}

// The gateway answers with Server-Sent Events; the payload sits on `data:` lines.
function parseGatewayBody(text) {
  const line = String(text || '').split('\n').find((entry) => entry.startsWith('data: '));
  try {
    return JSON.parse(line ? line.slice('data: '.length) : text);
  } catch (_) {
    throw Object.assign(new Error('Delhivery One returned an unreadable response'), { status: 502, errorCode: 'D1_ERROR' });
  }
}

async function postRpc(payload, requestId, token) {
  const { clientCms, realm, mcpUrl, timeoutMs } = config();
  let response;
  try {
    response = await fetch(mcpUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'x-hq-client-id': clientCms,
        'X-UCP-User-Email': '--',
        'X-UCP-Realm': realm,
        'X-Request-ID': requestId,
        'Content-Type': 'application/json',
        Accept: 'application/json, text/event-stream',
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    if (error && (error.name === 'TimeoutError' || error.name === 'AbortError')) {
      throw Object.assign(new Error('Delhivery One gateway timed out'), { status: 502, errorCode: 'D1_UNREACHABLE', cause: error });
    }
    throw Object.assign(new Error('Delhivery One gateway is unreachable'), { status: 502, errorCode: 'D1_UNREACHABLE', cause: error });
  }
  if (response.status === 401 || response.status === 403) {
    throw Object.assign(new Error(errorMessage(response.status, 'Delhivery One gateway error')), { status: 502, errorCode: 'D1_AUTH_FAILED' });
  }
  if (!response.ok) {
    throw Object.assign(new Error(errorMessage(response.status, 'Delhivery One gateway error')), { status: 502, errorCode: 'D1_ERROR' });
  }
  return parseGatewayBody(await response.text());
}

// Calls one gateway tool and returns its parsed result payload. A tool-level
// error (gateway HTTP 200 with isError content) surfaces as D1_TOOL_ERROR so
// callers can distinguish provider failures from transport failures.
async function callTool(name, args = {}) {
  if (!isEnabled()) throw Object.assign(new Error('Delhivery One is not configured. Set D1_CLIENT_ID, D1_CLIENT_SECRET, D1_AUTH_URL, D1_REALM, D1_CLIENT_CMS and D1_MCP_URL.'), { status: 503, errorCode: 'D1_NOT_CONFIGURED' });
  const requestId = crypto.randomUUID();
  const payload = { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args } };
  let data;
  try {
    data = await postRpc(payload, requestId, await getToken());
  } catch (error) {
    if (error && error.errorCode === 'D1_AUTH_FAILED') {
      // The cached token may have been revoked early; mint once more and retry.
      cachedToken = null;
      expiresAt = 0;
      data = await postRpc(payload, requestId, await getToken());
    } else {
      throw error;
    }
  }
  if (data && data.error) {
    throw Object.assign(new Error(`Delhivery One tool ${name} failed: ${data.error.message || 'unknown error'}`), { status: 502, errorCode: 'D1_TOOL_ERROR' });
  }
  const content = data && data.result && data.result.content;
  const text = Array.isArray(content) && content.length ? content[0].text : null;
  if (text == null) return data ? data.result : null;
  try {
    return JSON.parse(text);
  } catch (_) {
    return text;
  }
}

async function listTools() {
  if (cachedTools && Date.now() - toolsFetchedAt < TOOLS_CACHE_TTL_MS) return cachedTools;
  if (!isEnabled()) throw Object.assign(new Error('Delhivery One is not configured.'), { status: 503, errorCode: 'D1_NOT_CONFIGURED' });
  const data = await postRpc({ jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }, crypto.randomUUID(), await getToken());
  cachedTools = ((data && data.result && data.result.tools) || []).map((tool) => tool.name);
  toolsFetchedAt = Date.now();
  return cachedTools;
}

// Prepaid wallet balance and configuration for the configured client.
async function getWallet() {
  return callTool('get-wallet-details', {});
}

// Service activations (DOMESTIC, INTERNATIONAL, LTL, HYPERLOCAL) with HQ
// client credentials, billing and wallet references.
async function listClientMappings() {
  return callTool('list-client-mappings', {});
}

// B2C shipment search. Pass the same filters the gateway expects; pagination
// and newest-first ordering are defaulted.
async function searchShipments(args = {}) {
  return callTool('shipment-search', {
    search_on: ['oid'],
    search_term: '',
    page_size: 20,
    page: 1,
    field: 'manifested_at',
    direction: 'DESC',
    ...args,
  });
}

// Bulk B2C rate estimates. The gateway tool accepts one request's fields per
// call, so a batch is fanned out in parallel and merged into a single
// {responses:[...]} envelope. Each request needs a unique id; one is generated
// when omitted. Accepts a single request object or an array.
async function getRate(requests) {
  const items = (Array.isArray(requests) ? requests : [requests]).map((item, index) => ({
    id: `${item.shipping_mode || 'RATE'}_${Date.now()}_${index}`,
    ...item,
  }));
  const results = await Promise.all(items.map((item) => callTool('bulk-rate-calculator', item)));
  const responses = [];
  for (const result of results) {
    if (result && Array.isArray(result.responses)) responses.push(...result.responses);
    else responses.push(result);
  }
  return { responses };
}

// Full support-ticket detail, optionally with the conversation thread.
async function getTicket(ticketId, conversations = false) {
  if (!ticketId) throw Object.assign(new Error('A ticket id is required'), { status: 422 });
  return callTool('get-ticket-details', { ticket_id: ticketId, conversations: Boolean(conversations) });
}

module.exports = {
  isEnabled,
  callTool,
  listTools,
  getWallet,
  listClientMappings,
  searchShipments,
  getRate,
  getTicket,
  // Test-only: clears the in-memory token/tools cache between cases.
  _resetCache() {
    cachedToken = null;
    expiresAt = 0;
    mintPromise = null;
    cachedTools = null;
    toolsFetchedAt = 0;
  },
};
