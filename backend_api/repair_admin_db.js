
const db = require('./db');
const bcrypt = require('bcryptjs');

async function repairAdminTable() {
    try {
        console.log('Repairing admin_users table...');
        
        // 1. Add password column if it doesn't exist
        await db.query(`
            ALTER TABLE admin_users 
            ADD COLUMN IF NOT EXISTS password TEXT;
        `);
        console.log('✅ Password column verified.');

        // 2. Add name column if it doesn't exist
        await db.query(`
            ALTER TABLE admin_users 
            ADD COLUMN IF NOT EXISTS name TEXT;
        `);
        
        // 3. Set the superadmin password correctly (Hashed)
        const hashedPassword = await bcrypt.hash('SamanyuduKill@2026S', 10);
        
        // Insert or Update the first super admin
        await db.query(`
            INSERT INTO admin_users (email, password, role, name) 
            VALUES ('superadmin1@samanyudu.tv', $1, 'super_admin', 'Super Admin')
            ON CONFLICT (email) 
            DO UPDATE SET password = $1, role = 'super_admin';
        `, [hashedPassword]);

        console.log('✅ Admin accounts repaired with encrypted passwords.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Repair failed:', err);
        process.exit(1);
    }
}

repairAdminTable();
