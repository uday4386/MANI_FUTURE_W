const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { Pool } = require('pg');

function resolveSslConfig() {
    const flag = (process.env.DATABASE_SSL || '').toLowerCase();
    const pgsslmode = (process.env.PGSSLMODE || '').toLowerCase();

    if (flag === 'false' || flag === '0' || pgsslmode === 'disable') return false;
    if (flag === 'true' || flag === '1' || pgsslmode === 'require') return { rejectUnauthorized: false };

    return process.env.DATABASE_URL ? { rejectUnauthorized: false } : false;
}

// This Pool connects to your PostgreSQL database.
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
    ssl: resolveSslConfig()
});

pool.on('error', (err, client) => {
    console.error('Unexpected error on idle client', err);
    process.exit(-1);
});

module.exports = {
    query: (text, params) => pool.query(text, params),
};
