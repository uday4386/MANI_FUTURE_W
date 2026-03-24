const { Client } = require('pg');
const dotenv = require('dotenv');

dotenv.config();

async function applySchema() {
    const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false
    });

    try {
        await client.connect();
        console.log('Connected to database');

        const sql = `
            CREATE TABLE IF NOT EXISTS marriage_profiles (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                news_id UUID REFERENCES news(id) ON DELETE CASCADE,
                full_name VARCHAR,
                gender VARCHAR,
                date_of_birth DATE,
                age INT,
                profile_photo VARCHAR,
                location VARCHAR,
                native_place VARCHAR,
                religion VARCHAR,
                caste VARCHAR,
                sub_caste VARCHAR,
                mother_tongue VARCHAR,
                highest_education VARCHAR,
                college_name VARCHAR,
                occupation VARCHAR,
                company_name VARCHAR,
                annual_income VARCHAR,
                father_name VARCHAR,
                father_occupation VARCHAR,
                mother_name VARCHAR,
                mother_occupation VARCHAR,
                siblings VARCHAR,
                phone_number VARCHAR,
                email VARCHAR,
                whatsapp_number VARCHAR,
                is_contact_visible BOOLEAN DEFAULT false,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `;

        await client.query(sql);
        console.log('Table marriage_profiles created successfully');
    } catch (err) {
        console.error('Error applying schema:', err);
    } finally {
        await client.end();
    }
}

applySchema();
