const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const database = require('./database');

// Splits a plain SQL file (no procedures/delimiters) into statements. Only
// whole-line `--` comments are stripped; the SQL files keep comments that way.
function splitStatements(sql) {
  return sql.split(/\r?\n/).filter((line) => !/^\s*--/.test(line)).join('\n')
    .split(/;\s*(?:\n|$)/).map((statement) => statement.trim()).filter(Boolean);
}

// schema.mysql.sql is written for a fresh database, so CREATE TABLE is made
// idempotent here and duplicate indexes/columns are ignored. That lets the same
// file bring an existing database up to date with newly added tables and
// columns. Seeds are idempotent INSERT IGNORE / ON DUPLICATE KEY statements.
async function migrate() {
  if (!database.isConfigured()) return;
  database.getPool(); // fails fast with a clear message for a non-MySQL URL
  // A raw mysql2 connection is used on purpose: the app pool rewrites $1-style
  // placeholders, which would corrupt literal `$` values such as bcrypt hashes.
  const mysql = require('mysql2/promise');
  const conn = await mysql.createConnection({ uri: process.env.DATABASE_URL, connectTimeout: Number(process.env.DB_CONNECT_TIMEOUT_MS || 10000) });
  const files = [
    { name: 'schema.mysql.sql', schema: true },
    { name: 'seed.mysql.sql' },
    ...(process.env.NODE_ENV === 'production' ? [] : [{ name: 'seed.demo.mysql.sql' }]),
  ];
  try {
    const [[lock]] = await conn.query("SELECT GET_LOCK('signfix_migrate', 60) AS acquired");
    if (!lock.acquired) throw new Error('Could not acquire the migration lock');
    await conn.query('CREATE TABLE IF NOT EXISTS schema_migrations (name VARCHAR(190) PRIMARY KEY, checksum CHAR(64) NOT NULL, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    for (const file of files) {
      const sql = await fs.readFile(path.join(__dirname, '..', 'database', file.name), 'utf8');
      const checksum = crypto.createHash('sha256').update(sql).digest('hex');
      const [[current]] = await conn.query('SELECT checksum FROM schema_migrations WHERE name=?', [file.name]);
      if (current?.checksum === checksum) continue;
      for (let statement of splitStatements(sql)) {
        if (file.schema) statement = statement.replace(/^CREATE TABLE\s+(?!IF NOT EXISTS)/i, 'CREATE TABLE IF NOT EXISTS ');
        try {
          await conn.query(statement);
        } catch (error) {
          if (file.schema && [1061, 1060, 1826].includes(error.errno)) continue; // index/column/foreign key already exists
          throw Object.assign(error, { message: `${file.name}: ${error.message}` });
        }
      }
      await conn.query('INSERT INTO schema_migrations(name,checksum,applied_at) VALUES(?,?,NOW()) ON DUPLICATE KEY UPDATE checksum=VALUES(checksum),applied_at=NOW()', [file.name, checksum]);
    }
  } finally {
    await conn.query("SELECT RELEASE_LOCK('signfix_migrate')").catch(() => {});
    await conn.end();
  }
}

module.exports = migrate;
module.exports.splitStatements = splitStatements;
