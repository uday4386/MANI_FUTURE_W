const db = require('./db');

async function seedSuperAdmins() {
    const superAdmins = [
        { email: 'ydrkrishna@gmail.com', password: 'Samanyudu@2026$', name: 'Krishna YDR', role: 'super_admin' },
        { email: 'madubabu529@gmail.com', password: 'Samanyudu@2026$', name: 'Madubabu', role: 'super_admin' },
        { email: 'samanyudutv@gmail.com', password: 'Samanyudu@2026$', name: 'Samanyudu TV', role: 'super_admin' },
        { email: 'samanyuduguntur@gmail.com', password: 'Samanyudu@2026$', name: 'Samanyudu Guntur', role: 'super_admin' },
        { email: 'syncai@gmail.com', password: 'Samanyudu@2026$', name: 'Sync AI', role: 'super_admin' }
    ];

    try {
        console.log('Seeding requested super admins...');
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
    } finally {
        process.exit(0);
    }
}

seedSuperAdmins();
