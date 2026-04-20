const db = require('./db');
db.query("SELECT email, password, role FROM admin_users WHERE role = 'super_admin' LIMIT 1")
  .then(r => {
    console.log(JSON.stringify(r.rows[0]));
    process.exit(0);
  })
  .catch(e => {
    console.error(e);
    process.exit(1);
  });
