const db = require('./db');
db.query("UPDATE app_settings SET value = 'true' WHERE key = 'maintenance_mode'")
  .then(() => {
    console.log('Maintenance Mode ON');
    process.exit(0);
  })
  .catch(e => {
    console.error(e);
    process.exit(1);
  });
