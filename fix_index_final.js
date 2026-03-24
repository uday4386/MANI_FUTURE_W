const fs = require('fs');
const filePath = 'c:\\Users\\savya\\OneDrive\\Documents\\Samanyudu TV\\backend_api\\index.js';
let content = fs.readFileSync(filePath, 'utf8');

const oldCode = `        res.status(200).json({ status: 'ok', db: 'ok', msg: 'DigitalOcean API backend is running!' });
// Auto-initialize settings table
(async () => {
    try {
        await db.query('CREATE TABLE IF NOT EXISTS app_settings (key VARCHAR PRIMARY KEY, value JSONB)');
        await db.query("INSERT INTO app_settings (key, value) VALUES ('maintenance_mode', 'false') ON CONFLICT (key) DO NOTHING");
        console.log('✅ Settings table initialized');
    } catch (err) {
        console.error('❌ Failed to initialize settings table:', err.message);
    }
})();
    } catch (error) {`;

const newCode = `        res.status(200).json({ status: 'ok', db: 'ok', msg: 'DigitalOcean API backend is running!' });
    } catch (error) {`;

// Also add the init code at the bottom or top level
const initCode = `
// Auto-initialize settings table
(async () => {
    try {
        const db = require('./db');
        await db.query('CREATE TABLE IF NOT EXISTS app_settings (key VARCHAR PRIMARY KEY, value JSONB)');
        await db.query("INSERT INTO app_settings (key, value) VALUES ('maintenance_mode', 'false') ON CONFLICT (key) DO NOTHING");
        console.log('✅ Settings table initialized');
    } catch (err) {
        console.error('❌ Failed to initialize settings table:', err.message);
    }
})();
`;

if (content.includes('res.status(200).json({ status: \'ok\', db: \'ok\', msg: \'DigitalOcean API backend is running!\' });')) {
    // Just find the block manually
    const start = content.indexOf('res.status(200).json({ status: \'ok\', db: \'ok\', msg: \'DigitalOcean API backend is running!\' });');
    const end = content.indexOf('} catch (error) {', start);
    if (start !== -1 && end !== -1) {
        content = content.substring(0, start + 86) + "\n    } catch (error) {" + content.substring(end + 17);
        content += initCode;
        fs.writeFileSync(filePath, content, 'utf8');
        console.log("Successfully fixed index.js");
    } else {
        console.log("Could not find markers", { start, end });
    }
} else {
    console.log("Could not find base string");
}
