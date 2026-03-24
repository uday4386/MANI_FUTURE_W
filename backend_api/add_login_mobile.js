const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(filePath, 'utf8');

const loginMobileRoute = `
// 3b. Login with Mobile and Password
app.post('/api/auth/login-mobile', async (req, res) => {
    try {
        let { phone, password } = req.body;
        if (!phone || !password) return res.status(400).json({ error: 'Phone and password are required' });

        phone = phone.replace(/\\D/g, '');
        phone = phone.substring(phone.length - 10);

        const { rows } = await db.query('SELECT * FROM users WHERE phone = $1 AND password = $2', [phone, password]);
        if (rows.length === 0) {
            return res.status(401).json({ error: 'Invalid phone or password' });
        }

        const user = rows[0];
        res.json({
            success: true,
            user: { id: user.id, phone: user.phone, name: user.name || \`\${user.first_name || ''} \${user.last_name || ''}\`.trim() || 'User' }
        });
    } catch (err) {
        console.error("Error logging in via mobile:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

`;

if (!content.includes('/api/auth/login-mobile')) {
    const searchStr = "// 3. Login with Email and Password";
    if (content.includes(searchStr)) {
        content = content.replace(searchStr, loginMobileRoute + searchStr);
        fs.writeFileSync(filePath, content);
        console.log("login-mobile route added successfully.");
    } else {
        console.error("Search string not found.");
    }
} else {
    console.log("Route already exists.");
}
