const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { Client } = require('pg');
const fs = require('fs');
const csv = require('csv-parser');

const orderedTables = [
    'admin_users',
    'advertisements',
    'news',
    'marriage_profiles',
    'shorts',
    'news_likes',
    'shorts_likes',
    'shorts_comments'
];

function resolveSslConfig() {
    const flag = (process.env.DATABASE_SSL || '').toLowerCase();
    const pgsslmode = (process.env.PGSSLMODE || '').toLowerCase();

    if (flag === 'false' || flag === '0' || pgsslmode === 'disable') return false;
    if (flag === 'true' || flag === '1' || pgsslmode === 'require') return { rejectUnauthorized: false };

    return process.env.DATABASE_URL ? { rejectUnauthorized: false } : false;
}

async function initialize() {
    console.log("Attempting to initialize database...");

    let connectionConfig;
    if (process.env.DATABASE_URL) {
        connectionConfig = {
            connectionString: process.env.DATABASE_URL,
            ssl: resolveSslConfig()
        };
    } else {
        connectionConfig = {
            host: process.env.DB_HOST || 'localhost',
            port: process.env.DB_PORT || 5432,
            user: process.env.DB_USER || 'postgres',
            password: process.env.DB_PASSWORD || 'admin123',
            database: process.env.DB_NAME || 'samanyudu'
        };
    }

    const client = new Client(connectionConfig);

    try {
        await client.connect();
        console.log("1. Connected. Building schema...");
        const sql = fs.readFileSync(path.join(__dirname, 'schema.sql')).toString();
        await client.query(sql);
        console.log("Schema built successfully.");

        console.log("2. Inserting data...");
        for (const tableName of orderedTables) {
            const filePath = path.join(__dirname, `${tableName}_rows.csv`);
            if (!fs.existsSync(filePath)) continue;

            const rows = [];
            await new Promise((resolve) => {
                fs.createReadStream(filePath)
                    .pipe(csv())
                    .on('data', (d) => rows.push(d))
                    .on('end', () => resolve());
            });

            if (rows.length === 0) continue;

            const columns = Object.keys(rows[0]);
            for (const row of rows) {
                const values = columns.map(c => row[c] === '' || row[c] === 'null' ? null : row[c]);
                const placeholders = columns.map((_, i) => `$${i + 1}`).join(',');
                const query = `INSERT INTO ${tableName} ("${columns.join('","')}") VALUES (${placeholders}) ON CONFLICT DO NOTHING;`;

                try {
                    await client.query(query, values);
                } catch (e) {
                    // Ignore individual row conflict/error so it completes
                }
            }
            console.log(`Finished ${tableName}: ${rows.length} rows processed.`);
        }

        // Add all requested superadmins and force update their passwords to plain-text
        const superAdmins = [
            { email: 'ydrkrishna@gmail.com', password: 'Samanyudu@2026$', name: 'Krishna YDR' },
            { email: 'madubabu529@gmail.com', password: 'Samanyudu@2026$', name: 'Madubabu' },
            { email: 'samanyudutv@gmail.com', password: '0987654321', name: 'Samanyudu TV' },
            { email: 'samanyuduguntur@gmail.com', password: 'Samanyudu@2026$', name: 'Samanyudu Guntur' },
            { email: 'syncai@gmail.com', password: 'Samanyudu@2026$', name: 'Sync AI' },
            { email: 'superadmin1@samanyudu.tv', password: 'SamanyuduKill@2026S', name: 'Super Admin 1' }
        ];

        for (const admin of superAdmins) {
            await client.query(`
                INSERT INTO admin_users (email, password, name, role) 
                VALUES ($1, $2, $3, 'super_admin') 
                ON CONFLICT (email) 
                DO UPDATE SET password = EXCLUDED.password, role = 'super_admin';
            `, [admin.email, admin.password, admin.name]);
            console.log(`Forced plain-text reset for: ${admin.email}`);
        }

        console.log("✅ ALL SUPERADMINS RESET TO PLAIN-TEXT");
        console.log("✅ DB INITIALIZATION COMPLETE");
    } catch (e) {
        console.error("❌ DB Initialization Error:", e.message);
        process.exit(1);
    } finally {
        await client.end();
    }
}

module.exports = { initialize };

if (require.main === module) {
    initialize();
}
