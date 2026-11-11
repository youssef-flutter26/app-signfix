const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

// MariaDB stores JSON columns as LONGTEXT, so mysql2 returns them as strings
// (MySQL 8 returns parsed objects). The JSON columns declared in the schema are
// collected here so their values come back as objects on both servers.
function loadJsonColumns() {
  const qualified = new Set(), byName = new Map();
  let sql = '';
  try { sql = fs.readFileSync(path.join(__dirname, '..', 'database', 'schema.mysql.sql'), 'utf8'); } catch (_) { return { qualified, byName }; }
  for (const match of sql.matchAll(/CREATE TABLE (?:IF NOT EXISTS )?`?(\w+)`?\s*\(([\s\S]*?)\);/gi)) {
    for (const column of match[2].matchAll(/(?:^|[,(]\s*)`?(\w+)`?\s+(JSON|[A-Z]+)/gim)) {
      const isJson = column[2].toUpperCase() === 'JSON';
      if (isJson) qualified.add(`${match[1]}.${column[1]}`);
      byName.set(column[1], (byName.get(column[1]) ?? true) && isJson);
    }
  }
  return { qualified, byName };
}
const jsonColumns = loadJsonColumns();
const isJsonColumn = (field) => jsonColumns.qualified.has(`${field.orgTable}.${field.orgName}`) || jsonColumns.byName.get(field.orgName || field.name) === true;

function typeCast(field, next) {
  // BOOLEAN is TINYINT(1): return true/false like the rest of the code expects.
  if (field.type === 'TINY' && field.length === 1) {
    const value = field.string();
    return value === null ? null : value === '1';
  }
  if (field.type === 'BLOB' || field.type === 'VAR_STRING' || field.type === 'STRING') {
    // Computed JSON_OBJECT()/JSON_ARRAYAGG() values have no source table.
    const computed = !field.orgTable;
    if (!computed && !isJsonColumn(field)) return next();
    const value = field.string('utf8');
    if (value === null || (computed && !/^\s*[{[]/.test(value))) return value;
    try { return JSON.parse(value); } catch (_) { return value; }
  }
  return next();
}

// mysql2 would expand a plain object into `key = value` pairs; JSON columns
// expect the serialized document instead.
function toParam(value) {
  if (value === undefined) return null;
  if (value && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date) && !Buffer.isBuffer(value)) return JSON.stringify(value);
  return value;
}

// Queries are written with numbered $1 placeholders; they are rewritten to
// mysql2 `?` placeholders (a number may repeat, so values are re-ordered).
function toMysql(text, params = []) {
  const orderedParams = [];
  const sql = text.replace(/\$(\d+)/g, (_, n) => {
    orderedParams.push(toParam(params[Number(n) - 1]));
    return '?';
  });
  return { sql, values: orderedParams };
}

function toResult(rows) {
  return { rows: Array.isArray(rows) ? rows : [], rowCount: Array.isArray(rows) ? rows.length : rows.affectedRows || 0, insertId: rows.insertId };
}

// Bounds how long any single query may run (env DB_STATEMENT_TIMEOUT_MS) and
// how long connect() may wait for a free pool slot (env DB_QUERY_TIMEOUT_MS).
// Without these, a stalled database hangs API requests forever: the browser
// eventually aborts and the logs show ECONNABORTED with no actionable error.
// With these, the same situation fails fast with a 503 the client can retry.
const statementTimeoutMs = () => Number(process.env.DB_STATEMENT_TIMEOUT_MS || 8000);
const acquireTimeoutMs = () => Number(process.env.DB_QUERY_TIMEOUT_MS || 10000);

function withTimeout(promise, ms, error) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(error), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

const statementTimeoutError = () => Object.assign(new Error('Database query timed out'), { status: 503, errorCode: 'DB_STATEMENT_TIMEOUT' });
const poolExhaustedError = () => Object.assign(new Error('Database is busy. Please try again in a moment.'), { status: 503, errorCode: 'DB_POOL_EXHAUSTED' });

function wrapClient(conn) {
  return {
    async query(text, params) {
      const { sql, values } = toMysql(text, params);
      const [rows] = await withTimeout(conn.query(sql, values), statementTimeoutMs(), statementTimeoutError());
      return toResult(rows);
    },
    release: () => conn.release(),
  };
}

function createPool(config) {
  const pool = mysql.createPool({ dateStrings: ['DATE'], supportBigNumbers: true, typeCast, ...config });
  return {
    async query(text, params) {
      const { sql, values } = toMysql(text, params);
      const [rows] = await withTimeout(pool.query(sql, values), statementTimeoutMs(), statementTimeoutError());
      return toResult(rows);
    },
    async connect() {
      const conn = await withTimeout(pool.getConnection(), acquireTimeoutMs(), poolExhaustedError());
      return wrapClient(conn);
    },
    end: () => pool.end(),
  };
}

module.exports = { createPool, toMysql };
