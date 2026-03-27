require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const csv = require('csv-parser');

const orderedTables = [
    'admin_users',
    'advertisements',
    'news',
    'shorts',
    'news_likes',
    'shorts_likes',
    'shorts_comments'
];

async function importAllCsvFiles() {
    const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false
    });


    try {
        await client.connect();
        console.log("Connected to 'samanyudu' to import data via Streams...\n");

        for (const tableName of orderedTables) {
            const fileName = `${tableName}_rows.csv`;
            const filePath = path.join(__dirname, fileName);

            if (!fs.existsSync(filePath)) {
                console.warn(`Skipping missing export: ${fileName}`);
                continue;
            }

            console.log(`\nImporting to table 👉 ${tableName}...`);

            const rows = [];
            await new Promise((resolve, reject) => {
                fs.createReadStream(filePath)
                    .pipe(csv())
                    .on('data', (data) => rows.push(data))
                    .on('end', () => resolve())
                    .on('error', reject);
            });

            if (rows.length === 0) {
                console.log(`✅ Table ${tableName} is empty. Skipping.`);
                continue;
            }

            // Build bulk insert query
            const columns = Object.keys(rows[0]);

            for (const row of rows) {
                // Sanitize data (empty string -> null for dates, etc)
                const values = columns.map(c => row[c] === '' || row[c] === null ? null : row[c]);

                const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
                const query = `INSERT INTO ${tableName} ("${columns.join('", "')}") VALUES (${placeholders}) ON CONFLICT DO NOTHING;`;

                try {
                    await client.query(query, values);
                } catch (e) {
                    console.error(`Error on ${tableName} row:`, e.message);
                }
            }

            console.log(`✅ Success for ${tableName} (${rows.length} rows imported)!`);
        }

        console.log("\nData migration finished! Your local database is now an identical clone of Supabase.");

    } catch (error) {
        console.error("❌ Fatal Error connecting to PostgreSQL:", error.message);
    } finally {
        await client.end();
    }
}

importAllCsvFiles();
