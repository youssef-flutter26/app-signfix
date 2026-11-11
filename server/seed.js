// Applies the MySQL schema and seed data, and optionally creates or updates a
// super administrator. Usage (from the project root):
//   npm run db:seed
//   ADMIN_EMAIL=owner@example.com ADMIN_PASSWORD='Strong@Pass1' npm run db:seed
require('./config');
const bcrypt = require('bcryptjs');
const database = require('./database');
const migrate = require('./migrate');

async function upsertAdmin() {
  const email = String(process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || '';
  if (!email && !password) return null;
  if (!email || password.length < 8) throw new Error('ADMIN_EMAIL and an ADMIN_PASSWORD of at least 8 characters are both required');
  const pool = database.getPool();
  const role = (await pool.query("SELECT id FROM roles WHERE name='super_admin'")).rows[0];
  if (!role) throw new Error('super_admin role is missing; the seed did not run');
  const hash = await bcrypt.hash(password, 12);
  await pool.query(
    `INSERT INTO users(role_id,name,email,mobile,password_hash,status,verified_at) VALUES($1,$2,$3,$4,$5,'active',NOW())
     ON DUPLICATE KEY UPDATE role_id=VALUES(role_id),name=VALUES(name),mobile=COALESCE(VALUES(mobile),mobile),password_hash=VALUES(password_hash),status='active'`,
    [role.id, process.env.ADMIN_NAME || 'Administrator', email, process.env.ADMIN_MOBILE || null, hash],
  );
  return email;
}

async function counts() {
  const tables = ['roles', 'permissions', 'notification_templates', 'products', 'materials', 'lighting_options', 'service_categories', 'users'];
  const pool = database.getPool();
  const result = {};
  for (const table of tables) result[table] = Number((await pool.query(`SELECT COUNT(*) AS total FROM ${table}`)).rows[0].total);
  return result;
}

(async () => {
  if (!database.isConfigured()) throw new Error('DATABASE_URL is not set');
  await migrate();
  const admin = await upsertAdmin();
  console.log('Seed complete.', admin ? `Super admin ready: ${admin}` : 'No ADMIN_EMAIL given; no admin user changed.');
  console.table(await counts());
  await database.getPool().end();
})().catch((error) => {
  console.error('Seed failed:', error.message);
  process.exit(1);
});
