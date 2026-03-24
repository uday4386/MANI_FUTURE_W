const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'index.js');
let lines = fs.readFileSync(filePath, 'utf8').split('\n');

// 1. Add column fix to startup
const dbReadyLine = lines.findIndex(l => l.includes("const app = express();"));
if (dbReadyLine !== -1) {
    const columnFix = `
// Auto-fix database schema
(async () => {
    try {
        await db.query(\`
            DO $$ 
            BEGIN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='firebase_uid') THEN
                    ALTER TABLE users ADD COLUMN firebase_uid VARCHAR;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='name') THEN
                    ALTER TABLE users ADD COLUMN name VARCHAR;
                END IF;
            END $$;\`);
        console.log('Database schema checked and updated.');
    } catch (err) {
        console.error('Error auto-fixing schema:', err);
    }
})();
`;
    lines.splice(dbReadyLine + 1, 0, columnFix);
}

// 2. Replace Fast2SMS with 2Factor.in and add Firebase route
const startTarget = lines.findIndex(l => l.includes('app.post(\'/api/auth/send-otp\''));
const endTarget = lines.findIndex(l => l.includes('// 3. Login with Email and Password'));

if (startTarget !== -1 && endTarget !== -1) {
    const before = lines.slice(0, startTarget);
    const after = lines.slice(endTarget);

    const middle = [
        'app.post(\'/api/auth/send-otp\', async (req, res) => {',
        '    try {',
        '        let { phone } = req.body;',
        '        phone = phone.replace(/\\D/g, \'\');',
        '        if (phone.length === 10) phone = \'91\' + phone;',
        '',
        '        const apiKey = process.env.TWO_FACTOR_API_KEY;',
        '        if (!apiKey) {',
        '            return res.status(500).json({ error: \'TWO_FACTOR_API_KEY is missing on the server\' });',
        '        }',
        '',
        '        const otp = Math.floor(100000 + Math.random() * 900000).toString();',
        '        mobileOtpStore.set(phone.substring(phone.length - 10), { otp, expires: Date.now() + 10 * 60 * 1000 });',
        '',
        '        // 2Factor.in API call',
        '        const url = `https://2factor.in/API/V1/${apiKey}/SMS/${phone}/${otp}/OTP1`;',
        '        const response = await axios.get(url);',
        '        ',
        '        if (response.data.Status === \'Success\') {',
        '            return res.json({ success: true, message: \'OTP sent successfully via 2Factor\' });',
        '        }',
        '        return res.status(400).json({ error: \'Failed to send OTP\', details: response.data });',
        '    } catch (err) {',
        '        console.error(\'Error sending OTP via 2Factor:\', err);',
        '        res.status(500).json({ error: \'Internal Server Error sending OTP\' });',
        '    }',
        '});',
        '',
        'app.post(\'/api/auth/verify-otp\', async (req, res) => {',
        '    try {',
        '        let { phone, otp } = req.body;',
        '        phone = phone.replace(/\\D/g, \'\');',
        '        phone = phone.substring(phone.length - 10);',
        '        otp = String(otp || \'\').trim();',
        '',
        '        const storedData = mobileOtpStore.get(phone);',
        '        if (!storedData || storedData.otp !== otp || storedData.expires < Date.now()) {',
        '            return res.status(400).json({ error: \'Invalid or expired OTP\' });',
        '        }',
        '',
        '        return res.json({ success: true, message: \'OTP verified successfully\' });',
        '    } catch (err) {',
        '        console.error(\'Error verifying OTP:\', err.message);',
        '        return res.status(500).json({ error: \'Internal Server Error verifying OTP\' });',
        '    }',
        '});',
        '',
        'app.post(\'/api/auth/register-mobile\', async (req, res) => {',
        '    try {',
        '        let { firstName, lastName, phone, otp, password } = req.body;',
        '        if (!firstName || !lastName || !phone || !otp || !password) return res.status(400).json({ error: \'All fields are required\' });',
        '        phone = phone.replace(/\\D/g, \'\');',
        '        phone = phone.substring(phone.length - 10);',
        '',
        '        const storedData = mobileOtpStore.get(phone);',
        '        if (!storedData || storedData.otp !== otp || storedData.expires < Date.now()) {',
        '            return res.status(400).json({ error: \'Invalid or expired OTP\' });',
        '        }',
        '',
        '        const { rows: existing } = await db.query(\'SELECT * FROM users WHERE phone = $1\', [phone]);',
        '        if (existing.length > 0) return res.status(400).json({ error: \'Phone already registered\' });',
        '',
        '        const query = \'INSERT INTO users (first_name, last_name, phone, password, name) VALUES ($1, $2, $3, $4, $5) RETURNING *\';',
        '        const result = await db.query(query, [firstName, lastName, phone, password, `\${firstName} \${lastName}\`.trim()]);',
        '        mobileOtpStore.delete(phone);',
        '        res.json({ success: true, user: { id: result.rows[0].id, phone: result.rows[0].phone, name: result.rows[0].name } });',
        '    } catch (err) {',
        '        console.error("Error registering via mobile:", err);',
        '        res.status(500).json({ error: \'Internal Server Error\' });',
        '    }',
        '});',
        '',
        '// 2b. Register/Sync Firebase User',
        'app.post(\'/api/auth/register-firebase\', async (req, res) => {',
        '    try {',
        '        const { uid, email, firstName, lastName } = req.body;',
        '        if (!uid || !email || !firstName || !lastName) return res.status(400).json({ error: \'All fields are required\' });',
        '        const { rows } = await db.query(\'SELECT * FROM users WHERE email = $1\', [email]);',
        '        let user;',
        '        if (rows.length > 0) {',
        '            const updateResult = await db.query(\'UPDATE users SET first_name = $1, last_name = $2, firebase_uid = $3 WHERE email = $4 RETURNING *\', [firstName, lastName, uid, email]);',
        '            user = updateResult.rows[0];',
        '        } else {',
        '            const insertResult = await db.query(\'INSERT INTO users (email, first_name, last_name, name, firebase_uid) VALUES ($1, $2, $3, $4, $5) RETURNING *\', [email, firstName, lastName, `\${firstName} \${lastName}\`.trim(), uid]);',
        '            user = insertResult.rows[0];',
        '        }',
        '        res.json({ success: true, user: { id: user.id, email: user.email, name: user.name || `\${user.first_name} \${user.last_name}\`.trim() } });',
        '    } catch (err) {',
        '        console.error("Error syncing Firebase user:", err);',
        '        res.status(500).json({ error: \'Failed to sync user\' });',
        '    }',
        '});',
        ''
    ];

    fs.writeFileSync(filePath, [...before, ...middle, ...after].join('\n'));
    console.log("index.js completely patched.");
} else {
    console.error("Could not find start or end section for OTP patching.");
}
