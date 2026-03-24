const db = require('./db');

async function seedSuperAdmins() {
    const admins = [
        { email: 'superadmin1@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 1' },
        { email: 'superadmin2@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 2' },
        { email: 'superadmin3@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 3' },
        { email: 'superadmin4@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 4' },
    ];

    try {
        console.log('Seeding super admins...');
        for (const admin of admins) {
            await db.query(`
                INSERT INTO admin_users (email, password, name, role) 
                VALUES ($1, $2, $3, 'super_admin') 
                ON CONFLICT (email) DO NOTHING
            `, [admin.email, admin.password, admin.name]);
        }
        console.log('✅ Super admins seeded successfully!');
        process.exit(0);
    } catch (err) {
        console.error('❌ Seeding failed:', err);
        process.exit(1);
    }
}

seedSuperAdmins();
