const db = require('./db');

async function seedSuperAdmins() {
    const superAdmins = [
        { email: 'admin1@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 1', role: 'super_admin' },
        { email: 'admin2@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 2', role: 'super_admin' },
        { email: 'admin3@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 3', role: 'super_admin' },
        { email: 'admin4@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 4', role: 'super_admin' }
    ];

    try {
        console.log('Seeding super admins...');
        for (const admin of superAdmins) {
            await db.query(`
                INSERT INTO admin_users (email, password, name, role)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (email) DO UPDATE 
                SET password = EXCLUDED.password, name = EXCLUDED.name, role = EXCLUDED.role
            `, [admin.email, admin.password, admin.name, admin.role]);
            console.log(`- Seeded ${admin.email}`);
        }
        console.log('Super admins seeding complete.');
    } catch (error) {
        console.error('Error seeding super admins:', error);
    }
}

seedSuperAdmins();
