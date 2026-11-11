const app = require('./app');
const { host, port } = require('./config');
const migrate = require('./migrate');

async function start() {
  // Start listening first. Database migrations and optional realtime/AI services
  // must never block the HTTP server from becoming reachable on slow hosted
  // MySQL/Redis connections.
  const server=app.listen(port, host, () => console.log(`SignFix API listening on http://${host}:${port}`));
  const {isCorsOriginAllowed}=require('./config');

  migrate().catch((error) => {
    console.error('Background database migration failed:', error.message);
  });

  require('./services/realtimeService').initialize(server,isCorsOriginAllowed)
    .catch((error) => console.warn('Realtime service disabled:', error.message));

  try { require('./services/aiQueue').startWorker(); }
  catch (error) { console.warn('AI worker disabled:', error.message); }
  const shutdown = (signal) => {
    console.log(`${signal} received; closing SignFix API`);
    server.close(() => process.exit(0));
  };
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.once('SIGTERM', () => shutdown('SIGTERM'));
  return server;
}

if (require.main === module) {
  start().catch((error) => {
    console.error('SignFix API failed to start:', error);
    process.exit(1);
  });
}

module.exports = app;
module.exports.start = start;
