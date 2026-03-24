const fs = require('fs');
const path = require('path');
const indexPath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(indexPath, 'utf8');

// Replace CORS origin logic
const oldCors = `app.use(cors({
    origin: function (origin, callback) {
        if (!origin || allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV !== 'production') {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true
}));`;

const newCors = `app.use(cors({
    origin: '*',
    credentials: true
}));`;

if (content.indexOf('origin: function (origin, callback)') !== -1) {
    content = content.replace(/app\.use\(cors\(\{[\s\S]*?credentials: true\s*\}\)\);/, newCors);
    fs.writeFileSync(indexPath, content);
    console.log('✅ CORS updated to allow all origins');
} else {
    console.log('❌ CORS logic not found or already updated');
}
