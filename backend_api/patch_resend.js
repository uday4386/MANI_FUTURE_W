const fs = require('fs');
const path = require('path');
const indexPath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(indexPath, 'utf8');

// Add Resend Import if not present
if (content.indexOf("require('resend')") === -1) {
    const importMatch = content.match(/const nodemailer = require\('nodemailer'\);/);
    if (importMatch) {
        content = content.replace(importMatch[0], importMatch[0] + "\nconst { Resend } = require('resend');\nconst resend = new Resend(process.env.RESEND_API_KEY);");
        console.log('✅ Resend Import added');
    }
} else {
    console.log('ℹ️ Resend Import already exists');
}

// Replace Send OTP logic
const oldRoute = `app.post('/api/auth/send-email-otp', async (req, res) => {
    try {
        const { email } = req.body;
        console.log(\`[Email Auth] Request to send OTP to: \${email}\`);
        if (!email) return res.status(400).json({ error: 'Email is required' });

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        emailOtpStore.set(email, { otp, expires: Date.now() + 10 * 60 * 1000 }); // 10 mins

        const mailOptions = {
            from: process.env.SMTP_FROM,
            to: email,
            subject: 'Samanyudu TV - Verification Code',
            text: \`Your verification code is: \${otp}. This code will expire in 10 minutes.\`,
            html: \`<h3>Samanyudu TV Verification</h3><p>Your verification code is: <b>\${otp}</b></p><p>This code will expire in 10 minutes.</p>\`,
        };

        console.log(\`[Email Auth] Sending email using: \${process.env.SMTP_USER}\`);
        await transporter.sendMail(mailOptions);
        console.log(\`[Email Auth] OTP sent successfully to: \${email}\`);
        res.json({ success: true, message: 'OTP sent to email successfully' });
    } catch (err) {
        console.error("[Email Auth] Error sending email OTP:", err);
        res.status(500).json({ error: 'Failed to send email OTP', details: err.message });
    }
});`;

const newRoute = `app.post('/api/auth/send-email-otp', async (req, res) => {
    try {
        const { email } = req.body;
        console.log(\`[Email Auth] Request to send OTP to: \${email}\`);
        if (!email) return res.status(400).json({ error: 'Email is required' });

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        emailOtpStore.set(email, { otp, expires: Date.now() + 10 * 60 * 1000 }); // 10 mins

        console.log(\`[Email Auth] Sending email via Resend to: \${email}\`);
        
        const { data, error } = await resend.emails.send({
            from: process.env.RESEND_FROM || 'Samanyudu TV <onboarding@resend.dev>',
            to: email,
            subject: 'Samanyudu TV - Verification Code',
            html: \`<h3>Samanyudu TV Verification</h3><p>Your verification code is: <b>\${otp}</b></p><p>This code will expire in 10 minutes.</p>\`,
        });

        if (error) {
            console.error("[Resend Error]", error);
            throw new Error(error.message);
        }

        console.log(\`[Email Auth] OTP sent successfully via Resend:\`, data.id);
        res.json({ success: true, message: 'OTP sent to email successfully' });
    } catch (err) {
        console.error("[Email Auth] Error sending email OTP:", err);
        res.status(500).json({ error: 'Failed to send email OTP', details: err.message });
    }
});`;

if (content.indexOf('Sending email via Resend') === -1) {
    // regex search for the route
    const routeRegex = /app\.post\('\/api\/auth\/send-email-otp'[\s\S]*?\}\);/;
    if (content.match(routeRegex)) {
        content = content.replace(routeRegex, newRoute);
        console.log('✅ OTP Route updated to Resend');
    } else {
        console.log('❌ OTP Route logic not found');
    }
}

fs.writeFileSync(indexPath, content);
