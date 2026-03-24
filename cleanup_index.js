const fs = require('fs');
const filePath = 'c:\\Users\\savya\\OneDrive\\Documents\\Samanyudu TV\\backend_api\\index.js';
let content = fs.readFileSync(filePath, 'utf8');

// 1. Fix the messy health check and move init code out
const messyHealthCheck = /\/\/ HEALTH CHECK & ONE-TIME DB SETUP[\s\S]*?app\.get\('\/api\/health'[\s\S]*?\}\);/m;

const cleanHealthCheck = `// ==========================================
// HEALTH CHECK & ONE-TIME DB SETUP
// ==========================================
app.get('/api/health', async (req, res) => {
    try {
        await db.query('SELECT 1');
        res.status(200).json({ status: 'ok', db: 'ok', msg: 'DigitalOcean API backend is running!' });
    } catch (error) {
        console.error('Health check DB error:', error.message);
        res.status(500).json({ status: 'error', db: 'down', error: 'Database connection failed' });
    }
});

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

// Find first occurrence of HEALTH CHECK and replace the whole block
const searchStr = "// ==========================================\n// HEALTH CHECK & ONE-TIME DB SETUP\n// ==========================================";
const startIdx = content.indexOf(searchStr);
if (startIdx !== -1) {
    // Find the end of the route handler });
    const endMarker = "});";
    const endIdx = content.indexOf(endMarker, startIdx + searchStr.length);
    if (endIdx !== -1) {
        const fullBlockEndIdx = endIdx + endMarker.length;
        // Check if my previous failed patch left a mess
        const nextInit = content.indexOf("// Auto-initialize settings table", startIdx);
        let finalEndIdx = fullBlockEndIdx;
        if (nextInit !== -1 && nextInit < fullBlockEndIdx + 500) {
            // include the init code in the replacement range
            const initEnd = content.indexOf("})();", nextInit);
            if (initEnd !== -1) finalEndIdx = initEnd + 5;
        }

        content = content.substring(0, startIdx) + cleanHealthCheck + content.substring(finalEndIdx);
        fs.writeFileSync(filePath, content, 'utf8');
        console.log("Cleaned up index.js health check and init code");
    } else {
        console.error("Could not find end of health check");
    }
} else {
    console.error("Could not find health check start");
}
