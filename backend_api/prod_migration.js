
const { Pool } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

// Load PRODUCTION environment
dotenv.config({ path: path.join(__dirname, '.env.production') });

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false
});

async function applyFix() {
    console.log("Applying Marriage Schema Fix to PRODUCTION...");
    try {
        const query = `
            DO $$ 
            BEGIN
                -- Add marriage_details if it doesn't exist
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='news' AND column_name='marriage_details') THEN
                    ALTER TABLE news ADD COLUMN marriage_details JSONB;
                END IF;

                -- Ensure status column has the right constraints or exists
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='news' AND column_name='status') THEN
                    ALTER TABLE news ADD COLUMN status VARCHAR(20) DEFAULT 'published';
                END IF;

                -- Similarly for shorts
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shorts' AND column_name='status') THEN
                    ALTER TABLE shorts ADD COLUMN status VARCHAR(20) DEFAULT 'published';
                END IF;
                
                -- Similarly for ads
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='advertisements' AND column_name='status') THEN
                    ALTER TABLE advertisements ADD COLUMN status VARCHAR(20) DEFAULT 'published';
                END IF;
            END $$;
        `;
        await pool.query(query);
        console.log("SUCCESS: Marriage Schema Fix applied to Production DB.");
    } catch (err) {
        console.error("FAILED to apply fix:", err.message);
    } finally {
        await pool.end();
    }
}

applyFix();
