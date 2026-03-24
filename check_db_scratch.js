const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', 'backend_api', '.env') });

async function check() {
    const connectionConfig = {
        connectionString: process.env.DATABASE_URL || `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
        ssl: false
    };

    console.log("Connecting with:", connectionConfig.connectionString || "Fallback config");
    const client = new Client(connectionConfig);

    try {
        await client.connect();
        console.log("Connected successfully!");

        const res = await client.query('SELECT count(*) FROM news');
        console.log("News count:", res.rows[0].count);

        const marriageCount = await client.query("SELECT count(*) FROM news WHERE type IN ('marriage', 'పెళ్లి పందిరి', 'పెళ్ళి పందిరి')");
        console.log("Marriage articles count:", marriageCount.rows[0].count);

    } catch (err) {
        console.error("Connection error:", err.message);
    } finally {
        await client.end();
    }
}

check();
