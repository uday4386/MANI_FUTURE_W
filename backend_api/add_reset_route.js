const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(filePath, 'utf8');

const resetRoute = `
// Reset Password with Mobile OTP
app.post('/api/auth/reset-password-mobile', async (req, res) => {
    try {
        let { phone, otp, newPassword } = req.body;
        if (!phone || !otp || !newPassword) return res.status(400).json({ error: 'Phone, OTP and new password are required' });

        phone = phone.replace(/\\D/g, '');
        phone = phone.substring(phone.length - 10);

        const storedData = mobileOtpStore.get(phone);
        if (!storedData || storedData.otp !== otp || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        const { rowCount } = await db.query('UPDATE users SET password = $1 WHERE phone = $2', [newPassword, phone]);
        if (rowCount === 0) return res.status(404).json({ error: 'User not found' });

        mobileOtpStore.delete(phone);
        res.json({ success: true, message: 'Password reset successfully' });
    } catch (err) {
        console.error("Error resetting password:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

`;

if (!content.includes('/api/auth/reset-password-mobile')) {
    const searchStr = "// 3. Login with Email and Password";
    if (content.includes(searchStr)) {
        content = content.replace(searchStr, resetRoute + searchStr);
        fs.writeFileSync(filePath, content);
        console.log("reset-password-mobile route added successfully.");
    } else {
        console.error("Search string not found.");
    }
} else {
    console.log("Route already exists.");
}
