const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function migrate() {
    const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false
    });

    try {
        await client.connect();
        console.log("Connected to database.");

        const queries = [
            "ALTER TABLE shorts ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'published';",
            "ALTER TABLE shorts ADD COLUMN IF NOT EXISTS area VARCHAR DEFAULT 'General';",
            "ALTER TABLE shorts ADD COLUMN IF NOT EXISTS author VARCHAR DEFAULT 'Admin';",
            "ALTER TABLE advertisements ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'published';"
        ];

        for (const query of queries) {
            console.log(`Executing: ${query}`);
            await client.query(query);
        }

        console.log("Migration completed successfully.");
    } catch (err) {
        console.error("Migration error:", err.message);
    } finally {
        await client.end();
    }
}

migrate();
