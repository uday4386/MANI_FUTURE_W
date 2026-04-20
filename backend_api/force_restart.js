
const { execSync } = require('child_process');

async function forceRestart() {
    try {
        console.log('--- FORCED BACKEND RESTART ---');
        
        // 1. Try to kill anything on port 5000
        try {
            console.log('Killing anything on port 5000...');
            // Linux command to kill process on port
            execSync('fuser -k 5000/tcp || true'); 
        } catch (e) {
            console.log('Port 5000 was already empty or fuser failed.');
        }

        // 2. Kill existing PM2 process
        try {
            console.log('Stopping PM2...');
            execSync('pm2 delete samanyudu-api || true');
        } catch (e) {}

        // 3. Start fresh
        console.log('Starting fresh PM2 process...');
        execSync('pm2 start index.js --name samanyudu-api --watch');
        
        console.log('✅ Backend Force-Restarted successfully!');
        process.exit(0);
    } catch (err) {
        console.error('❌ Force-Restart failed:', err.message);
        process.exit(1);
    }
}

forceRestart();
