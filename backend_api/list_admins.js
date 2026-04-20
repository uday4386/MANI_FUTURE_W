
const db = require('./db');

async function listAdmins() {
    try {
        const { rows } = await db.query("SELECT email, role, district, password FROM admin_users");
        console.log('--- ALL ADMINS ---');
        console.log(JSON.stringify(rows, null, 2));
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

listAdmins();
