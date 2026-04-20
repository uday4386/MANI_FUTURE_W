
const db = require('./db');
const bcrypt = require('bcryptjs');

async function repairSaitanu() {
    try {
        const email = 'saitanu@gmail.com';
        const pass = '1234567';
        const hashedPassword = await bcrypt.hash(pass, 10);

        // First, clean up the broken record (the one with no email)
        await db.query("DELETE FROM admin_users WHERE email IS NULL OR email = ''");

        // Then, insert or update the correct account
        await db.query(`
            INSERT INTO admin_users (email, password, name, role, state, district)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (email) 
            DO UPDATE SET password = $2, name = $3, role = $4, state = $5, district = $6
        `, [email, hashedPassword, 'Saitanu', 'sub_admin', 'Andhra Pradesh', 'Anantapur']);

        console.log(`✅ Successfully repaired and secured: ${email}`);
        process.exit(0);
    } catch (err) {
        console.error('❌ Repair failed:', err);
        process.exit(1);
    }
}

repairSaitanu();
