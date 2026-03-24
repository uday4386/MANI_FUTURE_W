const db = require('./db');

async function fixSchema() {
    try {
        console.log("Checking users table schema...");

        // Add firebase_uid column if it doesn't exist
        await db.query(`
            DO $$ 
            BEGIN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='firebase_uid') THEN
                    ALTER TABLE users ADD COLUMN firebase_uid VARCHAR;
                END IF;
                
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='name') THEN
                    ALTER TABLE users ADD COLUMN name VARCHAR;
                END IF;
            END $$;
        `);

        console.log("Schema updated successfully.");
        process.exit(0);
    } catch (err) {
        console.error("Error updating schema:", err);
        process.exit(1);
    }
}

fixSchema();
