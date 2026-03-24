const fs = require('fs');
const path = require('path');

const filePath = 'c:\\Users\\savya\\OneDrive\\Documents\\Samanyudu TV\\backend_api\\index.js';
let content = fs.readFileSync(filePath, 'utf8');

// Add table initialization
const healthCheckPattern = /\/\/ ==========================================\n\/\/ HEALTH CHECK & ONE-TIME DB SETUP\n\/\/ ==========================================\napp\.get\('\/api\/health', async \(req, res\) => \{[\s\S]*?\}\);/;

const initCode = `
// Auto-initialize settings table
(async () => {
    try {
        await db.query('CREATE TABLE IF NOT EXISTS app_settings (key VARCHAR PRIMARY KEY, value JSONB)');
        await db.query("INSERT INTO app_settings (key, value) VALUES ('maintenance_mode', 'false') ON CONFLICT (key) DO NOTHING");
        console.log('✅ Settings table initialized');
    } catch (err) {
        console.error('❌ Failed to initialize settings table:', err.message);
    }
})();`;

if (content.indexOf('// Auto-initialize settings table') === -1) {
    const healthCheckEndMatch = content.match(/\/\/ HEALTH CHECK & ONE-TIME DB SETUP[\s\S]*?\}\);/);
    if (healthCheckEndMatch) {
        const endOfHealthCheck = healthCheckEndMatch.index + healthCheckEndMatch[0].length;
        content = content.substring(0, endOfHealthCheck) + initCode + content.substring(endOfHealthCheck);
        fs.writeFileSync(filePath, content, 'utf8');
        console.log("Successfully updated index.js with init code");
    } else {
        console.error("Could not find health check in index.js");
        process.exit(1);
    }
} else {
    console.log("Init code already present in index.js");
}
