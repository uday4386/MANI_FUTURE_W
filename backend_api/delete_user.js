const { Client } = require('pg');
require('dotenv').config();

async function deleteUser() {
    const client = new Client({ 
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false
    });
    try {
        await client.connect();
        
        // Find user first
        const findRes = await client.query('SELECT id FROM users WHERE email = $1', ['22jk1a0599@gmail.com']);
        if (findRes.rows.length === 0) {
            console.log('User not found.');
            return;
        }
        
        const userId = findRes.rows[0].id;
        console.log('Deleting user with ID:', userId);

        // Delete from related tables (using explicit casting if needed)
        await client.query('DELETE FROM news_likes WHERE user_id::text = $1', [userId]);
        await client.query('DELETE FROM shorts_likes WHERE user_id::text = $1', [userId]);
        await client.query('DELETE FROM saved_items WHERE user_id::text = $1', [userId]);
        await client.query('DELETE FROM shorts_comments WHERE user_id::text = $1', [userId]);
        
        const res = await client.query('DELETE FROM users WHERE id = $1', [userId]);
        console.log('User record deleted successfully.');
    } catch (err) {
        console.error('Error deleting user:', err);
    } finally {
        await client.end();
    }
}

deleteUser();
