
const db = require('./db');
const bcrypt = require('bcryptjs');

async function globalSecurityLock() {
    try {
        const { rows } = await db.query("SELECT id, email, password FROM admin_users");
        console.log(`Checking ${rows.length} accounts...`);

        for (const row of rows) {
            // If the password doesn't start with $2y$ or $2b$ (crypt signature), it's plain text
            if (!row.password.startsWith('$2b$') && !row.password.startsWith('$2y$')) {
                console.log(`🔒 Securing account: ${row.email}`);
                const hash = await bcrypt.hash(row.password, 10);
                await db.query("UPDATE admin_users SET password = $1 WHERE id = $2", [hash, row.id]);
            }
        }

        console.log('🏁 GLOBAL SECURITY LOCK COMPLETE. All accounts are now encrypted.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Lock failed:', err);
        process.exit(1);
    }
}

globalSecurityLock();
