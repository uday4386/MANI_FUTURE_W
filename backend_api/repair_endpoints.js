app.post('/api/user/:id/sync-saved', async (req, res) => {
    try {
        const { id } = req.params;
        const { news, shorts } = req.body; // Arrays of IDs

        if (news && Array.isArray(news)) {
            for (const itemId of news) {
                await db.query('INSERT INTO saved_items (user_id, item_id, item_type) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING', [id, itemId, 'news']);
            }
        }
        if (shorts && Array.isArray(shorts)) {
            for (const itemId of shorts) {
                await db.query('INSERT INTO saved_items (user_id, item_id, item_type) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING', [id, itemId, 'shorts']);
            }
        }
        res.json({ success: true });
    } catch (error) {
        console.error('Error syncing saved items:', error);
        res.status(500).json({ error: 'Failed to sync saved items' });
    }
});

app.post('/api/auth/register-email', async (req, res) => {
    try {
        const { firstName, lastName, email, otp, password } = req.body;
        if (!firstName || !lastName || !email || !otp || !password) {
            return res.status(400).json({ error: 'All fields are required' });
        }

        const storedData = emailOtpStore.get(email);
        if (!storedData || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        if (storedData.otp !== String(otp).trim() || storedData.type !== 'signup') {
            return res.status(400).json({ error: 'Invalid OTP' });
        }

        const name = `${firstName} ${lastName}`;
        const { rows: existingUser } = await db.query('SELECT * FROM users WHERE email = $1', [email]);
        
        if (existingUser.length > 0) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        const { rows } = await db.query(
            'INSERT INTO users (first_name, last_name, name, email, password) VALUES ($1, $2, $3, $4, $5) RETURNING *',
            [firstName, lastName, name, email, password.trim()]
        );
        const user = rows[0];

        emailOtpStore.delete(email);
        res.json({ success: true, user });
    } catch (err) {
        console.error('Email registration error:', err);
        res.status(500).json({ error: 'Registration failed' });
    }
});

app.post('/api/auth/send-email-otp', async (req, res) => {
    try {
        const { email, type = 'signup' } = req.body;
        if (!email) return res.status(400).json({ error: 'Email is required' });

        const { rows: userCheck } = await db.query('SELECT 1 FROM users WHERE email = $1', [email]);
        if (type === 'signup' && userCheck.length > 0) {
            return res.status(400).json({ error: 'Email already registered. Please login.' });
        }
        if (type === 'reset' && userCheck.length === 0) {
            return res.status(404).json({ error: 'No account found with this email' });
        }

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        emailOtpStore.set(email, { otp, type, expires: Date.now() + 10 * 60 * 1000 });
