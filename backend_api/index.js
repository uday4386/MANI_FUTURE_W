const fs = require('fs');
const path = require('path');
const crashLogPath = path.join(__dirname, 'crash_report.log');

// EMERGENCY CRASH RECORDER
process.on('uncaughtException', (err) => {
    const msg = `\n[${new Date().toISOString()}] FATAL CRASH: ${err.stack || err}\n`;
    try { fs.appendFileSync(crashLogPath, msg); } catch (e) {}
    console.error(msg);
    process.exit(1);
});

const bcrypt = require('bcryptjs');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');

const cors = require('cors');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const archiver = require('archiver');

const fetch = require('node-fetch'); // For AuthKey API
// const { api } = require('./services/api');
const db = require('./db');
// const { pipeline, env } = require('@xenova/transformers');
const axios = require('axios');
const nodemailer = require('nodemailer');
const { Resend } = require('resend');
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;
const puppeteer = require('puppeteer');
const admin = require('firebase-admin');

// Initialize Firebase Admin for Push Notifications
try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin initialized for notifications.');
} catch (error) {
    console.error('Error initializing Firebase Admin:', error.message);
}

// Push Notification Helper
async function sendPushNotification(title, body, newsId, type = 'news') {
    try {
        const message = {
            notification: {
                title: title,
                body: body
            },
            data: {
                id: newsId.toString(),
                type: type
            },
            topic: 'news'
        };
        const response = await admin.messaging().send(message);
        console.log(`Notification sent for ${type} ${newsId}:`, response);
    } catch (error) {
        console.error('Error sending push notification:', error);
    }
}

const app = express();
app.set('trust proxy', 1); // Enable trust proxy for DigitalOcean/Nginx


// Auto-fix database schema
(async () => {
    try {
        await db.query(`
            DO $$ 
            BEGIN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='firebase_uid') THEN
                    ALTER TABLE users ADD COLUMN firebase_uid VARCHAR;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='name') THEN
                    ALTER TABLE users ADD COLUMN name VARCHAR;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='advertisements' AND column_name='status') THEN
                    ALTER TABLE advertisements ADD COLUMN status VARCHAR DEFAULT 'published';
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='advertisements' AND column_name='is_active') THEN
                    ALTER TABLE advertisements ADD COLUMN is_active BOOLEAN DEFAULT false;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='news' AND column_name='status') THEN
                    ALTER TABLE news ADD COLUMN status VARCHAR DEFAULT 'published';
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shorts' AND column_name='status') THEN
                    ALTER TABLE shorts ADD COLUMN status VARCHAR DEFAULT 'published';
                END IF;
                CREATE TABLE IF NOT EXISTS app_settings (
                    key VARCHAR PRIMARY KEY,
                    value JSONB,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'marriage_profiles_news_id_key') THEN
                    ALTER TABLE marriage_profiles ADD CONSTRAINT marriage_profiles_news_id_key UNIQUE (news_id);
                END IF;
            END $$;`);
        console.log('Database schema checked and updated.');
    } catch (err) {
        console.error('Error auto-fixing schema:', err);
    }
})();

const port = process.env.PORT || 5000;
const useLocal = process.env.USE_LOCAL === 'true'; // Set to false for production / cloud

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir);
}
const uploadStaticOptions = {
    setHeaders: (res) => {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET,HEAD,OPTIONS');
        res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    }
};
app.use('/api/uploads', express.static(uploadsDir, uploadStaticOptions));
app.use('/uploads', express.static(uploadsDir, uploadStaticOptions));

// Email Transporter
const transporter = (process.env.SMTP_HOST && process.env.SMTP_PORT && process.env.SMTP_USER && process.env.SMTP_PASS)
    ? nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT, 10),
        secure: process.env.SMTP_PORT === '465',
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
        },
        tls: {
            rejectUnauthorized: false
        }
    })
    : null;

// In-memory OTP store (Use Redis for production)
const mobileOtpStore = new Map();
const emailOtpStore = new Map();

// Middleware
const allowedOrigins = [
    'http://localhost:5173',
    'http://localhost:8099',
    'http://localhost:8080',
    'http://localhost:5000',
    'http://localhost:3001',
    'http://localhost:3000',
    'http://localhost:8085',
    'http://127.0.0.1:8099',
    'http://127.0.0.1:8080',
    'http://192.168.29.208:5000',
    'http://192.168.29.208:5173',
    'https://samanyudutv.in',
    'https://www.samanyudutv.in',
    'https://admin.samanyudutv.in',
    'https://api.samanyudutv.in',
    'http://localhost:3002',
    'http://127.0.0.1:3002',
    process.env.ADMIN_URL,
    process.env.MOBILE_WEB_URL
].filter(Boolean);

const localhostOriginPattern = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i;

app.use(cors({
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps) or matching origins
        if (!origin || allowedOrigins.indexOf(origin) !== -1 || localhostOriginPattern.test(origin)) {
            callback(null, true);
        } else {
            console.error('[CORS Error] Origin not allowed:', origin);
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin', 'x-requester-email'],
    exposedHeaders: ['Content-Disposition', 'Content-Type']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/api/health', async (req, res) => {
    try {
        await db.query('SELECT 1');
        res.status(200).json({ status: 'healthy', database: 'connected', version: '1.0.1' });
    } catch (err) {
        res.status(500).json({ status: 'unhealthy', database: 'error', error: err.message });
    }
});
app.use((err, req, res, next) => {
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        console.error('Invalid JSON payload:', err.message);
        return res.status(400).json({ error: 'Invalid JSON payload' });
    }
    return next(err);
});

// R2 Storage Configuration
function hasR2Config() {
    return Boolean(
        process.env.R2_BUCKET_NAME &&
        process.env.R2_ACCESS_KEY_ID &&
        process.env.R2_SECRET_ACCESS_KEY &&
        process.env.CLOUDFLARE_ACCOUNT_ID
    );
}

function getS3Client() {
    if (!hasR2Config()) {
        return null;
    }

    return new S3Client({
        region: 'auto',
        endpoint: `https://${process.env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
        credentials: {
            accessKeyId: process.env.R2_ACCESS_KEY_ID,
            secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
        },
        forcePathStyle: true,
    });
}

// Optimized for production: Use disk storage for large video uploads
// This prevents high RAM usage and server crashes during video processing
const diskStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const tmpDir = path.join(uploadsDir, 'tmp');
        if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });
        cb(null, tmpDir);
    },
    filename: (req, file, cb) => {
        const fileExt = path.extname(file.originalname);
        cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${fileExt}`);
    }
});

const upload = multer({
    storage: diskStorage,
    limits: { fileSize: 500 * 1024 * 1024 }, // 500MB limit for high-quality production videos
});

// Middleware to catch Multer errors (like file too large)
const handleUploadError = (err, req, res, next) => {
    if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({ error: 'à°«à±ˆà°²à± à°ªà°°à°¿à°®à°¾à°£à°‚ 500MB à°•à°‚à°Ÿà±‡ à°Žà°•à±à°•à±à°µ à°‰à°‚à°¦à°¿. à°¦à°¯à°šà±‡à°¸à°¿ à°šà°¿à°¨à±à°¨ à°«à±ˆà°²à±â€Œà°¨à± à°…à°ªà±â€Œà°²à±‹à°¡à± à°šà±‡à°¯à°‚à°¡à°¿. (File too large, 500MB limit)' });
        }
        return res.status(400).json({ error: `à°…à°ªà±â€Œà°²à±‹à°¡à± à°²à±‹à°ªà°‚: ${err.message}` });
    }
    next(err);
};

// ==========================================
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

app.get('/api/init-db', async (req, res) => {
    try {
        const { initialize } = require('./init_render');
        await initialize();
        res.status(200).json({ status: 'ok', msg: 'Database initialized successfully!' });
    } catch (err) {
        console.error('Initialization Error:', err);
        res.status(500).json({ error: 'DB init failed' });
    }
});

// ==========================================
// AUTHENTICATION (FAST2SMS OTP)
// ==========================================
const FAST2SMS_API_KEY = process.env.FAST2SMS_API_KEY || '';
const MESSAGE_CENTRAL_CUSTOMER_ID = process.env.MESSAGE_CENTRAL_CUSTOMER_ID || '';
const MESSAGE_CENTRAL_API_KEY = process.env.MESSAGE_CENTRAL_API_KEY || '';
const TWO_FACTOR_API_KEY = process.env.TWO_FACTOR_API_KEY || '';

// Helper to get Message Central Auth Token
async function getMessageCentralToken() {
    try {
        const url = `https://cpaas.messagecentral.com/auth/v1/authentication/token?customerId=${MESSAGE_CENTRAL_CUSTOMER_ID}&key=${MESSAGE_CENTRAL_API_KEY}&scope=NEW`;
        const response = await axios.post(url); // Often works as POST or GET
        return response.data.token;
    } catch (err) {
        console.error('Error generating Message Central token:', err.message);
        return null;
    }
}


function normalizeIndianPhone(phone = '') {
    let normalizedPhone = String(phone).replace(/\D/g, '');
    if (normalizedPhone.length === 12 && normalizedPhone.startsWith('91')) {
        normalizedPhone = normalizedPhone.substring(2);
    }
    return normalizedPhone;
}

function isValidIndianMobile(phone = '') {
    return /^\d{10}$/.test(phone);
}

app.post('/api/auth/send-otp', async (req, res) => {
    try {
        let { phone } = req.body;
        phone = phone.replace(/\D/g, '');
        if (phone.length === 10) phone = '91' + phone;

        const cleanPhone10 = phone.substring(phone.length - 10);
        const phoneWith91 = '91' + cleanPhone10;
        const { rows: userCheck } = await db.query('SELECT 1 FROM users WHERE phone = $1', [cleanPhone10]);
        const { type } = req.body;

        if (type === 'signup' && userCheck.length > 0) {
            return res.status(400).json({ error: 'This mobile number is already registered. Please login.' });
        }
        if ((type === 'reset' || type === 'login') && userCheck.length === 0) {
            return res.status(404).json({ error: 'This mobile number is not registered yet. Please sign up first.' });
        }

        // Generate 4-digit OTP as per Approved Template 'OTP_TEMPLATE'
        const otp = Math.floor(1000 + Math.random() * 9000).toString();

        // 1. Primary: 2Factor.in with Transactional API (POST)
        if (process.env.TWO_FACTOR_API_KEY) {
            try {
                console.log(`[OTP] Sending Transactional SMS to ${phoneWith91} using VIAENT...`);
                const response = await axios.post(`https://2factor.in/API/V1/${process.env.TWO_FACTOR_API_KEY}/ADDON_SERVICES/SEND/TSMS`, {
                    From: 'VIAENT',
                    To: phoneWith91,
                    TemplateName: 'OTP_TEMPLATE',
                    VAR1: otp
                });

                if (response.data.Status === 'Success') {
                    mobileOtpStore.set(cleanPhone10, { otp, expires: Date.now() + 10 * 60 * 1000 });
                    return res.json({ success: true, message: 'OTP sent successfully via Transactional SMS' });
                } else {
                    console.error('2Factor API returned error:', response.data);
                }
            } catch (err) {
                console.error('2Factor Transactional API failed:', err.response?.data || err.message);
            }
        }

        // 2. Fallback: Fast2SMS
        if (process.env.FAST2SMS_API_KEY) {
            try {
                const url = `https://www.fast2sms.com/dev/bulkV2?authorization=${process.env.FAST2SMS_API_KEY}&route=otp&variables_values=${otp}&numbers=${cleanPhone10}`;
                const response = await axios.get(url);
                if (response.data.return) {
                    mobileOtpStore.set(cleanPhone10, { otp, expires: Date.now() + 10 * 60 * 1000 });
                    return res.json({ success: true, message: 'OTP sent successfully via backup SMS' });
                }
            } catch (err) {
                console.error('Fast2SMS fallback failed:', err.message);
            }
        }

        return res.status(400).json({ error: 'Failed to send OTP. Please try again later.' });
    } catch (err) {
        console.error('Error sending OTP:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
app.post('/api/auth/verify-otp', async (req, res) => {
    try {
        let { phone, otp } = req.body;
        phone = phone.replace(/\D/g, '');
        phone = phone.substring(phone.length - 10);
        otp = String(otp || '').trim();

        const storedData = mobileOtpStore.get(phone);
        if (!storedData || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        if (storedData.use_mc) {
            try {
                const token = await getMessageCentralToken();
                if (!token) throw new Error('Failed to get MC token');

                const validateUrl = `https://api.messagecentral.com/verification/v3/validate?mobileNumber=${phone}&verificationCode=${otp}`;
                const response = await axios.get(validateUrl, {
                    headers: { 'authToken': token }
                });

                if (response.data.responseCode === 200 && response.data.data.verificationStatus === 'VERIFIED') {
                    // Mark as verified in our store so register/reset routes can trust it
                    mobileOtpStore.set(phone, { ...storedData, verified: true });
                    return res.json({ success: true, message: 'OTP verified successfully' });
                }
                return res.status(400).json({ error: 'Invalid or expired OTP from Message Central' });
            } catch (err) {
                console.error('Message Central Validation Error:', err.response?.data || err.message);
                return res.status(500).json({ error: 'Verification service error' });
            }
        }

        if (storedData.otp !== otp) {
            return res.status(400).json({ error: 'Invalid OTP' });
        }

        return res.json({ success: true, message: 'OTP verified successfully' });
    } catch (err) {
        console.error('Error verifying OTP:', err.message);
        return res.status(500).json({ error: 'Internal Server Error verifying OTP' });
    }
});

app.post('/api/auth/register-mobile', async (req, res) => {
    try {
        let { firstName, lastName, phone, otp, password } = req.body;
        if (!firstName || !lastName || !phone || !otp || !password) return res.status(400).json({ error: 'All fields are required' });
        phone = phone.replace(/\D/g, '');
        phone = phone.substring(phone.length - 10);

        const storedData = mobileOtpStore.get(phone);
        if (!storedData || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        // If using MC, it must have been marked as verified by the verify-otp route
        if (storedData.use_mc) {
            if (!storedData.verified) {
                try {
                    const token = await getMessageCentralToken();
                    const validateUrl = `https://api.messagecentral.com/verification/v3/validate?mobileNumber=${phone}&verificationCode=${otp}`;
                    const response = await axios.get(validateUrl, { headers: { 'authToken': token } });
                    if (response.data.responseCode !== 200 || response.data.data.verificationStatus !== 'VERIFIED') {
                        return res.status(400).json({ error: 'Invalid OTP' });
                    }
                } catch (err) {
                    console.error('MC Validation failed in register-mobile:', err.message);
                    return res.status(500).json({ error: 'OTP validation failed' });
                }
            }
        } else if (storedData.otp !== otp) {
            return res.status(400).json({ error: 'Invalid OTP' });
        }

        const { rows: existing } = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);
        if (existing.length > 0) return res.status(400).json({ error: 'Phone already registered' });

        const passTrimmed = String(password).trim();
        const query = 'INSERT INTO users (first_name, last_name, phone, password, name) VALUES ($1, $2, $3, $4, $5) RETURNING *';
        const result = await db.query(query, [firstName, lastName, phone, passTrimmed, `${firstName} ${lastName}`.trim()]);
        mobileOtpStore.delete(phone);
        res.json({ success: true, user: { id: result.rows[0].id, phone: result.rows[0].phone, name: result.rows[0].name } });
    } catch (err) {
        console.error("Error registering via mobile:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// 2b. Register/Sync Firebase User
app.post('/api/auth/register-firebase', async (req, res) => {
    try {
        const { uid, email, firstName, lastName } = req.body;
        if (!uid || !email) return res.status(400).json({ error: 'UID and Email are required' });

        const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [email]);
        let user;

        if (rows.length > 0) {
            // Update existing user - only update names if provided
            let query = 'UPDATE users SET firebase_uid = $1';
            let params = [uid];

            if (firstName && lastName) {
                query += ', first_name = $2, last_name = $3, name = $4';
                params.push(firstName, lastName, `${firstName} ${lastName}`.trim());
            }

            query += ' WHERE email = $' + (params.length + 1) + ' RETURNING *';
            params.push(email);

            const updateResult = await db.query(query, params);
            user = updateResult.rows[0];
        } else {
            // New user - use provided names or default to "User"
            const fName = firstName || 'User';
            const lName = lastName || '';
            const fullName = `${fName} ${lName}`.trim();

            const insertResult = await db.query(
                'INSERT INTO users (email, first_name, last_name, name, firebase_uid) VALUES ($1, $2, $3, $4, $5) RETURNING *',
                [email, fName, lName, fullName, uid]
            );
            user = insertResult.rows[0];
        }
        res.json({ success: true, user: { id: user.id, email: user.email, name: user.name || `${user.first_name} ${user.last_name}`.trim() } });
    } catch (err) {
        console.error("Error syncing Firebase user:", err);
        res.status(500).json({ error: 'Failed to sync user' });
    }
});

// 2c. Register/Sync Firebase Phone User
app.post('/api/auth/register-firebase-phone', async (req, res) => {
    try {
        let { uid, phone, firstName, lastName } = req.body;
        if (!uid || !phone) return res.status(400).json({ error: 'UID and Phone are required' });

        phone = phone.replace(/\D/g, '');
        phone = phone.substring(phone.length - 10);

        // Check if user exists by phone
        const { rows } = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);
        let user;

        if (rows.length > 0) {
            // Update existing user with UID
            const updateResult = await db.query(
                'UPDATE users SET firebase_uid = $1 WHERE phone = $2 RETURNING *',
                [uid, phone]
            );
            user = updateResult.rows[0];
        } else {
            // Create new user
            const fName = firstName || 'User';
            const lName = lastName || '';
            const fullName = `${fName} ${lName}`.trim();

            const insertResult = await db.query(
                'INSERT INTO users (phone, first_name, last_name, name, firebase_uid) VALUES ($1, $2, $3, $4, $5) RETURNING *',
                [phone, fName, lName, fullName, uid]
            );
            user = insertResult.rows[0];
        }

        res.json({
            success: true,
            user: {
                id: user.id,
                phone: user.phone,
                name: user.name || `${user.first_name} ${user.last_name}`.trim()
            }
        });
    } catch (err) {
        console.error("Error syncing Firebase phone user:", err);
        res.status(500).json({ error: 'Failed to sync user' });
    }
});


// Reset Password with Mobile OTP
app.post('/api/auth/reset-password-mobile', async (req, res) => {
    try {
        let { phone, otp, newPassword } = req.body;
        if (!phone || !otp || !newPassword) return res.status(400).json({ error: 'Phone, OTP and new password are required' });

        phone = phone.replace(/\D/g, '');
        phone = phone.substring(phone.length - 10);

        const storedData = mobileOtpStore.get(phone);
        if (!storedData || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        if (storedData.use_mc) {
            if (!storedData.verified) {
                try {
                    const token = await getMessageCentralToken();
                    const validateUrl = `https://api.messagecentral.com/verification/v3/validate?mobileNumber=${phone}&verificationCode=${otp}`;
                    const response = await axios.get(validateUrl, { headers: { 'authToken': token } });
                    if (response.data.responseCode !== 200 || response.data.data.verificationStatus !== 'VERIFIED') {
                        return res.status(400).json({ error: 'Invalid OTP' });
                    }
                } catch (err) {
                    return res.status(500).json({ error: 'OTP validation failed' });
                }
            }
        } else if (storedData.otp !== String(otp).trim()) {
            console.log(`[Reset] OTP mismatch for ${phone}. Input: ${otp}, Stored: ${storedData?.otp}`);
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        console.log(`[Reset] Updating password for ${phone}. New length: ${newPassword.length}`);
        const { rowCount } = await db.query('UPDATE users SET password = $1 WHERE phone = $2', [await bcrypt.hash(newPassword.trim(), 10), phone]);

        if (rowCount === 0) {
            console.warn(`[Reset] Found no user with phone ${phone}`);
            return res.status(404).json({ error: 'Account not found for this phone number' });
        }

        mobileOtpStore.delete(phone);
        res.json({ success: true, message: 'Password reset successfully' });
    } catch (err) {
        console.error("Error resetting password:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});


// 3b. Login with Mobile and Password
app.post('/api/auth/login-mobile', async (req, res) => {
    try {
        let { phone, password } = req.body;
        if (!phone || !password) return res.status(400).json({ error: 'Phone and password are required' });

        phone = phone.replace(/\D/g, '');
        phone = phone.substring(phone.length - 10);
        const passTrimmed = String(password).trim();

        console.log(`[Login] Attempt for ${phone}`);
        const { rows } = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);

        if (rows.length === 0 || !(await bcrypt.compare(passTrimmed, rows[0].password))) {
            return res.status(401).json({ error: 'Invalid phone or password' });
        }

        const user = rows[0];
        console.log(`[Login] Success for ${user.id} (${phone})`);
        res.json({
            success: true,
            user: { id: user.id, phone: user.phone, name: user.name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || 'User' }
        });
    } catch (err) {
        console.error("Error logging in via mobile:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/auth/login-otp', async (req, res) => {
    try {
        let { phone, otp } = req.body;
        if (!phone || !otp) return res.status(400).json({ error: 'Phone and OTP are required' });

        phone = phone.replace(/\D/g, '');
        phone = phone.substring(phone.length - 10);

        const storedData = mobileOtpStore.get(phone);
        if (!storedData || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        if (storedData.use_mc) {
            try {
                const token = await getMessageCentralToken();
                const validateUrl = `https://api.messagecentral.com/verification/v3/validate?mobileNumber=${phone}&verificationCode=${otp}`;
                const response = await axios.get(validateUrl, { headers: { 'authToken': token } });
                if (response.data.responseCode !== 200 || response.data.data.verificationStatus !== 'VERIFIED') {
                    return res.status(400).json({ error: 'Invalid OTP' });
                }
            } catch (err) {
                return res.status(500).json({ error: 'OTP validation service error' });
            }
        } else if (storedData.otp !== String(otp).trim()) {
            return res.status(400).json({ error: 'Invalid OTP' });
        }

        const { rows } = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);
        if (rows.length === 0) {
            return res.status(404).json({ error: 'No account found for this phone. Please sign up first.' });
        }

        const user = rows[0];
        mobileOtpStore.delete(phone);
        res.json({
            success: true,
            user: { id: user.id, phone: user.phone, name: user.name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || 'User' }
        });
    } catch (err) {
        console.error("Error logging in via OTP:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// 3. Login with Email and Password
app.post('/api/auth/login-email', async (req, res) => {
    try {
        const { email, password } = req.body;
        const passTrimmed = String(password || '').trim();

        const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [email]);

        if (rows.length === 0 || !(await bcrypt.compare(passTrimmed, rows[0].password))) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        const user = rows[0];
        res.json({
            success: true,
            user: { id: user.id, email: user.email, name: `${user.first_name || ''} ${user.last_name || ''}`.trim() || 'User' }
        });
    } catch (err) {
        console.error("Error logging in:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Update Profile API
app.put('/api/user/:id/profile', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, phone, oldName } = req.body;

        // Split name fallback just in case we still rely on first/last
        const first_name = name.split(' ')[0] || '';
        const last_name = name.substring(first_name.length).trim() || '';

        // Update user
        const { rows } = await db.query(
            'UPDATE users SET name = $1, first_name = $2, last_name = $3, phone = $4 WHERE id = $5 RETURNING *',
            [name, first_name, last_name, phone, id]
        );

        if (rows.length === 0) return res.status(404).json({ error: 'User not found' });

        // Update comments by this user
        await db.query('UPDATE shorts_comments SET user_name = $1 WHERE user_id = $2', [name, id]);

        // Update news author
        if (oldName && oldName.trim() !== '') {
            await db.query('UPDATE news SET author = $1 WHERE author = $2', [name, oldName]);
        }

        res.json({ success: true, user: rows[0] });
    } catch (error) {
        console.error('Error updating profile:', error);
        res.status(500).json({ error: 'Failed to update user profile' });
    }
});


// ==========================================
// ADMIN PORTAL ROUTES
// ==========================================

// Admin Login
app.post('/api/admin/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const { rows } = await db.query('SELECT id, email, name, role, state, district, password FROM admin_users WHERE email = $1', [email]);

        if (rows.length === 0 || password !== rows[0].password) {
            return res.status(401).json({ error: 'Invalid admin credentials' });
        }

        res.json({ success: true, user: rows[0] });
    } catch (error) {
        console.error('Admin login error:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Manage Reporters (Super Admin Only)
app.get('/api/admin/reporters', async (req, res) => {
    try {
        const { rows } = await db.query("SELECT id, email, password, name, role, state, district, created_at FROM admin_users WHERE role = 'sub_admin' ORDER BY created_at DESC");
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch reporters' });
    }
});

app.post('/api/admin/reporters', async (req, res) => {
    try {
        const { email, password, name, state, district } = req.body;
        const query = 'INSERT INTO admin_users (email, password, name, state, district, role) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, email, name, state, district';
        const { rows } = await db.query(query, [email, password, name, state, district, 'sub_admin']);
        res.status(201).json(rows[0]);
    } catch (error) {
        if (error.code === '23505') return res.status(400).json({ error: 'Email already exists' });
        res.status(500).json({ error: 'Failed to create reporter' });
    }
});

app.put('/api/admin/reporters/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const keys = Object.keys(updates);
        if (keys.length === 0) return res.status(400).json({ error: 'No fields to update' });

        const setClause = keys.map((k, i) => `"${k}" = $${i + 1}`).join(', ');
        const values = Object.values(updates);
        values.push(id);

        const query = `UPDATE admin_users SET ${setClause} WHERE id = $${values.length} RETURNING id, email, password, name, state, district, role;`;
        const { rows } = await db.query(query, values);

        if (rows.length === 0) return res.status(404).json({ error: 'Reporter not found' });
        res.json(rows[0]);
    } catch (error) {
        console.error('Error updating reporter:', error);
        res.status(500).json({ error: 'Failed to update reporter' });
    }
});

app.delete('/api/admin/reporters/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('DELETE FROM admin_users WHERE id = $1', [id]);
        res.status(204).send();
    } catch (error) {
        res.status(500).json({ error: 'Failed to delete reporter' });
    }
});

// Manage Super Admins (Master Admin Only: syncai@gmail.com)
app.get('/api/admin/super_admins', async (req, res) => {
    try {
        const requester = req.headers['x-requester-email'];
        if (requester !== 'syncai@gmail.com') return res.status(403).json({ error: 'Forbidden. Only syncai@gmail.com can manage super admins.' });

        const { rows } = await db.query("SELECT id, email, password, name, role, state, district, created_at FROM admin_users WHERE role = 'super_admin' ORDER BY created_at DESC");
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch super admins' });
    }
});

app.post('/api/admin/super_admins', async (req, res) => {
    try {
        const requester = req.headers['x-requester-email'];
        if (requester !== 'syncai@gmail.com') return res.status(403).json({ error: 'Forbidden' });

        const { email, password, name } = req.body;
        const query = 'INSERT INTO admin_users (email, password, name, role) VALUES ($1, $2, $3, $4) RETURNING id, email, name, role';
        const { rows } = await db.query(query, [email, password, name, 'super_admin']);
        res.status(201).json(rows[0]);
    } catch (error) {
        if (error.code === '23505') return res.status(400).json({ error: 'Email already exists' });
        res.status(500).json({ error: 'Failed to create super admin' });
    }
});

app.put('/api/admin/super_admins/:id', async (req, res) => {
    try {
        const requester = req.headers['x-requester-email'];
        if (requester !== 'syncai@gmail.com') return res.status(403).json({ error: 'Forbidden' });

        const { id } = req.params;
        const updates = req.body;
        const keys = Object.keys(updates);
        if (keys.length === 0) return res.status(400).json({ error: 'No fields to update' });

        const setClause = keys.map((k, i) => `"${k}" = $${i + 1}`).join(', ');
        const values = Object.values(updates);
        values.push(id);

        const query = `UPDATE admin_users SET ${setClause} WHERE id = $${values.length} RETURNING id, email, password, name, role;`;
        const { rows } = await db.query(query, values);

        if (rows.length === 0) return res.status(404).json({ error: 'Super Admin not found' });
        res.json(rows[0]);
    } catch (error) {
        res.status(500).json({ error: 'Failed to update super admin' });
    }
});

app.delete('/api/admin/super_admins/:id', async (req, res) => {
    try {
        const requester = req.headers['x-requester-email'];
        if (requester !== 'syncai@gmail.com') return res.status(403).json({ error: 'Forbidden' });

        const { id } = req.params;
        await db.query("DELETE FROM admin_users WHERE id = $1 AND email != 'syncai@gmail.com'", [id]);
        res.status(204).send();
    } catch (error) {
        res.status(500).json({ error: 'Failed to delete super admin' });
    }
});

// Maintenance Mode
app.get('/api/admin/settings/maintenance', async (req, res) => {
    try {
        const { rows } = await db.query("SELECT value FROM app_settings WHERE key = 'maintenance_mode'");
        const enabled = rows.length > 0 ? rows[0].value : false;
        res.json({ enabled });
    } catch (error) {
        console.error('Fetch maintenance error:', error);
        res.status(500).json({ error: 'Failed to fetch maintenance status' });
    }
});

app.post('/api/admin/settings/maintenance', async (req, res) => {
    try {
        const { enabled } = req.body;
        await db.query("INSERT INTO app_settings (key, value) VALUES ('maintenance_mode', $1) ON CONFLICT (key) DO UPDATE SET value = $1", [JSON.stringify(enabled)]);
        res.json({ success: true, enabled });
    } catch (error) {
        console.error('Update maintenance error:', error);
        res.status(500).json({ error: 'Failed to update maintenance status' });
    }
});

// ==========================================
// MIGRATED ROUTES: NEWS
// ==========================================

app.get('/api/admin/news/archive', async (req, res) => {
    try {
        const query = `
            SELECT n.*, 
                   (SELECT json_build_object(
                       'full_name', m.full_name, 'gender', m.gender, 'date_of_birth', m.date_of_birth,
                       'age', m.age, 'profile_photo', m.profile_photo, 'location', m.location,
                       'native_place', m.native_place, 'religion', m.religion, 'caste', m.caste,
                       'sub_caste', m.sub_caste, 'mother_tongue', m.mother_tongue,
                       'highest_education', m.highest_education, 'college_name', m.college_name,
                       'occupation', m.occupation, 'company_name', m.company_name,
                       'annual_income', m.annual_income, 'father_name', m.father_name,
                       'father_occupation', m.father_occupation, 'mother_name', m.mother_name,
                       'mother_occupation', m.mother_occupation, 'siblings', m.siblings,
                       'phone_number', m.phone_number, 'email', m.email,
                       'whatsapp_number', m.whatsapp_number, 'is_contact_visible', m.is_contact_visible
                   ) FROM marriage_profiles m WHERE m.news_id = n.id) as marriage_details
            FROM news n
            ORDER BY n.timestamp DESC
        `;
        const { rows } = await db.query(query);
        const requestedFormat = String(req.query.format || '').toLowerCase();
        const forceJson = requestedFormat === 'json';
        const forceDoc = requestedFormat === 'doc' || requestedFormat === 'word' || requestedFormat === 'docx';

        const downloadJsonBackup = () => {
            const fileName = `Samanyudu_TV_News_Archive_${Date.now()}.json`;
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
            res.send(JSON.stringify(rows, null, 2));
        };

        const escapeHtml = (value) =>
            String(value ?? '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');

        if (forceJson) {
            return downloadJsonBackup();
        }

        let htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>SAMANYUDU TV - News Archive</title>
            <style>
                *, *::before, *::after { box-sizing: border-box; }
                body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; margin: 0; padding: 0; background: #fff; color: #333; width: 100%; }
                .header { text-align: center; background-color: #0f172a; color: #eab308; padding: 40px 20px; border-bottom: 5px solid #eab308; margin-bottom: 30px; }
                .header h1 { margin: 0; font-size: 36px; letter-spacing: 2px; text-transform: uppercase; }
                .header p { margin: 10px 0 0 0; color: #cbd5e1; font-size: 14px; }
                .container { width: 100%; padding: 0 50px; }
                .news-item { page-break-inside: avoid; border-bottom: 2px solid #e2e8f0; padding-bottom: 30px; margin-bottom: 30px; width: 100%; }
                .news-item img { display: block; max-width: 100%; max-height: 400px; object-fit: contain; margin: 20px auto 0 auto; border-radius: 8px; }
                h2 { color: #0f172a; margin: 0 0 15px 0; font-size: 26px; line-height: 1.3; }
                .meta-table { width: 100%; border-collapse: collapse; margin-bottom: 20px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; font-size: 13px; color: #64748b; }
                .meta-table td { padding: 15px; text-align: left; vertical-align: top; border-right: 1px solid #e2e8f0; width: 20%; }
                .meta-table td:last-child { border-right: none; }
                .meta-table strong { display: block; color: #334155; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; margin-bottom: 5px; }
                .description { white-space: pre-wrap; line-height: 1.7; color: #334155; font-size: 15px; }
                .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #94a3b8; padding: 30px 0; page-break-inside: avoid; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>SAMANYUDU TV</h1>
                <p>Official News Archive | Generated on ${new Date().toLocaleDateString()}</p>
                <p>Total Articles: ${rows.length}</p>
            </div>
            <div class="container">
        `;

        const formatDescription = (desc) => {
            if (!desc) return '';
            return escapeHtml(desc).replace(/\n/g, '<br/>');
        };

        rows.forEach(item => {
            htmlContent += `
            <div class="news-item">
                <h2>${escapeHtml(item.title || 'Untitled')}</h2>
                <table class="meta-table">
                    <tr>
                        <td><strong>Date</strong> ${escapeHtml(item.timestamp ? new Date(item.timestamp).toLocaleString() : 'N/A')}</td>
                        <td><strong>Area</strong> ${escapeHtml(item.area || 'N/A')}</td>
                        <td><strong>Category</strong> ${escapeHtml(item.type || 'N/A')}</td>
                        <td><strong>Reporter</strong> ${escapeHtml(item.author || 'N/A')}</td>
                        <td><strong>Live Link</strong> ${item.live_link ? `<a href="${escapeHtml(item.live_link)}" target="_blank" rel="noopener noreferrer">Watch Live</a>` : 'N/A'}</td>
                    </tr>
                </table>
                <div class="description">${formatDescription(item.description)}</div>
                ${item.image_url ? `<img src="${escapeHtml(item.image_url)}" alt="News Image"/>` : ''}
            </div>
            `;
        });

        htmlContent += `
            </div>
            <div class="footer">
                &copy; ${new Date().getFullYear()} SAMANYUDU TV. All Rights Reserved.
            </div>
        </body>
        </html>
        `;

        if (forceDoc) {
            const fileName = `Samanyudu_TV_News_Archive_${Date.now()}.doc`;
            // Set headers specifically for MS Word
            res.setHeader('Content-Type', 'application/msword; charset=UTF-8');
            res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);

            // Embed images as base64 for Word compatibility
            const processedRows = await Promise.all(rows.map(async (item) => {
                let base64Image = null;
                if (item.image_url) {
                    try {
                        const response = await axios.get(item.image_url, { responseType: 'arraybuffer' });
                        const buffer = Buffer.from(response.data, 'binary').toString('base64');
                        const contentType = response.headers['content-type'];
                        base64Image = `data:${contentType};base64,${buffer}`;
                    } catch (err) {
                        console.error('Image fetch error for Word:', err.message);
                    }
                }
                return { ...item, embedded_image: base64Image };
            }));

            // Simpler HTML for Word compatibility and better Telugu support
            const wordHtml = `
            <html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
            <head>
                <meta charset="utf-8">
                <style>
                    body { font-family: 'Arial Unicode MS', 'Segoe UI', serif; }
                    h1 { color: #0f172a; text-align: center; border-bottom: 2px solid #eab308; }
                    .news-item { margin-bottom: 40px; border-bottom: 1px solid #ccc; padding-bottom: 20px; }
                    .meta { color: #555; font-size: 10pt; margin-bottom: 10px; }
                    .description { font-size: 11pt; line-height: 1.5; }
                </style>
            </head>
            <body>
                <h1>SAMANYUDU TV - News Archive</h1>
                <p style="text-align:center">Generated on ${new Date().toLocaleString()}</p>
                <hr>
                ${processedRows.map(item => `
                    <div class="news-item">
                        <h2 style="color:#1e293b">${escapeHtml(item.title)}</h2>
                        <div class="meta">
                            <b>Date:</b> ${new Date(item.timestamp).toLocaleString()} | 
                            <b>Area:</b> ${escapeHtml(item.area)} | 
                            <b>Category:</b> ${escapeHtml(item.type)} | 
                            <b>Reporter:</b> ${escapeHtml(item.author)}
                        </div>
                        <div class="description">${formatDescription(item.description)}</div>
                        ${item.embedded_image ? `<br><img src="${item.embedded_image}" width="600" style="max-width:100%">` : ''}
                    </div>
                `).join('')}
            </body>
            </html>`;

            return res.send(`\uFEFF${wordHtml}`);
        }

        const launchOptions = {
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-web-security']
        };
        if (process.env.PUPPETEER_EXECUTABLE_PATH) {
            launchOptions.executablePath = process.env.PUPPETEER_EXECUTABLE_PATH;
        }

        let browser = null;
        try {
            browser = await puppeteer.launch(launchOptions);
            const page = await browser.newPage();
            await page.setContent(htmlContent, { waitUntil: 'domcontentloaded', timeout: 120000 });

            // Wait for image load with per-image timeout so backup can't hang forever.
            await page.evaluate(async () => {
                const images = Array.from(document.querySelectorAll('img'));
                await Promise.all(images.map((img) => {
                    if (img.complete) return Promise.resolve();
                    return new Promise((resolve) => {
                        const timeout = setTimeout(resolve, 8000);
                        img.addEventListener('load', () => {
                            clearTimeout(timeout);
                            resolve();
                        }, { once: true });
                        img.addEventListener('error', () => {
                            clearTimeout(timeout);
                            resolve();
                        }, { once: true });
                    });
                }));
            });

            const pdfBuffer = await page.pdf({
                format: 'A4',
                printBackground: true,
                margin: { top: '0px', right: '0px', bottom: '0px', left: '0px' }
            });

            res.setHeader('Content-Type', 'application/pdf');
            res.setHeader('Content-Disposition', `attachment; filename="Samanyudu_TV_News_Archive_${Date.now()}.pdf"`);
            res.send(pdfBuffer);
        } catch (pdfError) {
            console.error('PDF archive failed, sending JSON fallback:', pdfError.message);
            downloadJsonBackup();
        } finally {
            if (browser) {
                await browser.close().catch(() => null);
            }
        }
    } catch (error) {
        console.error('Archive failed:', error);
        res.status(500).json({ error: 'Failed to archive data' });
    }
});

app.delete('/api/admin/news/wipe', async (req, res) => {
    try {
        await db.query('DELETE FROM news');
        res.status(204).send();
    } catch (error) {
        console.error('Wipe failed:', error);
        res.status(500).json({ error: 'Failed to wipe data' });
    }
});

app.get('/api/news/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const query = `
            SELECT n.*, 
                   (SELECT json_build_object(
                       'full_name', m.full_name, 'gender', m.gender, 'date_of_birth', m.date_of_birth,
                       'age', m.age, 'profile_photo', m.profile_photo, 'location', m.location,
                       'native_place', m.native_place, 'religion', m.religion, 'caste', m.caste,
                       'sub_caste', m.sub_caste, 'mother_tongue', m.mother_tongue,
                       'highest_education', m.highest_education, 'college_name', m.college_name,
                       'occupation', m.occupation, 'company_name', m.company_name,
                       'annual_income', m.annual_income, 'father_name', m.father_name,
                       'father_occupation', m.father_occupation, 'mother_name', m.mother_name,
                       'mother_occupation', m.mother_occupation, 'siblings', m.siblings,
                       'phone_number', m.phone_number, 'email', m.email,
                       'whatsapp_number', m.whatsapp_number, 'is_contact_visible', m.is_contact_visible
                   ) FROM marriage_profiles m WHERE m.news_id = n.id) as marriage_details
            FROM news n
            WHERE n.id = $1
        `;
        const { rows } = await db.query(query, [id]);
        if (rows.length === 0) return res.status(404).json({ error: 'News not found' });
        res.json(rows[0]);
    } catch (error) {
        console.error('Error fetching single news:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.get('/api/news', async (req, res) => {
    try {
        const { district, role, status } = req.query;
        let query = `
            SELECT n.*, 
                   (SELECT json_build_object(
                       'full_name', m.full_name, 'gender', m.gender, 'date_of_birth', m.date_of_birth,
                       'age', m.age, 'profile_photo', m.profile_photo, 'location', m.location,
                       'native_place', m.native_place, 'religion', m.religion, 'caste', m.caste,
                       'sub_caste', m.sub_caste, 'mother_tongue', m.mother_tongue,
                       'highest_education', m.highest_education, 'college_name', m.college_name,
                       'occupation', m.occupation, 'company_name', m.company_name,
                       'annual_income', m.annual_income, 'father_name', m.father_name,
                       'father_occupation', m.father_occupation, 'mother_name', m.mother_name,
                       'mother_occupation', m.mother_occupation, 'siblings', m.siblings,
                       'phone_number', m.phone_number, 'email', m.email,
                       'whatsapp_number', m.whatsapp_number, 'is_contact_visible', m.is_contact_visible
                   ) FROM marriage_profiles m WHERE m.news_id = n.id) as marriage_details
            FROM news n
        `;
        let params = [];
        let whereClauses = [];

        if (role === 'sub_admin' && district) {
            whereClauses.push(`n.area = $${params.length + 1}`);
            params.push(district);
        }

        // Status Filtering: Default to 'published' for public requests
        const requestedStatus = status?.toString().toLowerCase();

        if (requestedStatus === 'all') {
            // No status filter applied - returns everything
            console.log('[DEBUG] Fetching ALL news (pending + published)');
        } else if (requestedStatus && requestedStatus !== 'published') {
            // Filter by specific status (pending, rejected, etc.)
            whereClauses.push(`n.status = $${params.length + 1}`);
            params.push(requestedStatus);
        } else {
            // Default: Only show published news
            whereClauses.push(`n.status = 'published'`);
        }

        if (whereClauses.length > 0) {
            query += ' WHERE ' + whereClauses.join(' AND ');
        }

        console.log('[DEBUG] News Query Executing:', query, 'with params:', params);

        query += ' ORDER BY n.timestamp DESC';
        const { rows } = await db.query(query, params);
        res.json(rows);
    } catch (error) {
        console.error('Error fetching news:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/news', async (req, res) => {
    try {
        const {
            title, description, category, img_url, image_url, video_url, location,
            is_breaking, live_link, status, author, area, type, marriage_details
        } = req.body;

        // Normalize fields
        const finalImageUrl = img_url || image_url;
        const finalArea = area || location;
        const finalType = type || category;
        if (!title || !description || !finalArea) {
            return res.status(400).json({ error: 'title, description, and area/location are required' });
        }
        const query = `
      INSERT INTO news(title, description, area, type, image_url, video_url, is_breaking, live_link, status, author)
      VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *;
        `;
        const values = [title, description, finalArea, finalType, finalImageUrl, video_url, is_breaking || false, live_link, status || 'pending', author || 'User'];
        const { rows } = await db.query(query, values);
        const news = rows[0];

        // Trigger Notification if Published
        if (news.status === 'published') {
            sendPushNotification(
                news.is_breaking ? '🚨 BREAKING NEWS' : 'New Update',
                news.title,
                news.id
            );
        }

        // Handle Matrimonial Profile if category is Marriage
        if ((finalType === 'Marriage' || finalType === 'à°ªà±†à°³à±à°²à°¿ à°ªà°‚à°¦à°¿à°°à°¿') && marriage_details) {
            const m = marriage_details;
            const mQuery = `
                INSERT INTO marriage_profiles (
                    news_id, full_name, gender, date_of_birth, age, profile_photo, 
                    location, native_place, religion, caste, sub_caste, mother_tongue, 
                    highest_education, college_name, occupation, company_name, annual_income, 
                    father_name, father_occupation, mother_name, mother_occupation, siblings, 
                    phone_number, email, whatsapp_number, is_contact_visible
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)
            `;
            const mValues = [
                news.id,
                m.full_name ?? null,
                m.gender ?? null,
                m.date_of_birth ?? null,
                m.age ? parseInt(m.age) : null,
                m.profile_photo ?? null,
                m.location ?? null,
                m.native_place ?? null,
                m.religion ?? null,
                m.caste ?? null,
                m.sub_caste ?? null,
                m.mother_tongue ?? null,
                m.highest_education ?? null,
                m.college_name ?? null,
                m.occupation ?? null,
                m.company_name ?? null,
                m.annual_income ?? null,
                m.father_name ?? null,
                m.father_occupation ?? null,
                m.mother_name ?? null,
                m.mother_occupation ?? null,
                m.siblings ?? null,
                m.phone_number ?? null,
                m.email ?? null,
                m.whatsapp_number ?? null,
                m.is_contact_visible === true || m.is_contact_visible === 'true'
            ];
            await db.query(mQuery, mValues);

            // Re-fetch to include marriage data in response
            const fullNewsResult = await db.query(`
                SELECT n.*, 
                       (SELECT json_build_object(
                           'full_name', m.full_name, 'gender', m.gender, 'date_of_birth', m.date_of_birth,
                           'age', m.age, 'profile_photo', m.profile_photo, 'location', m.location,
                           'native_place', m.native_place, 'religion', m.religion, 'caste', m.caste,
                           'sub_caste', m.sub_caste, 'mother_tongue', m.mother_tongue,
                           'highest_education', m.highest_education, 'college_name', m.college_name,
                           'occupation', m.occupation, 'company_name', m.company_name,
                           'annual_income', m.annual_income, 'father_name', m.father_name,
                           'father_occupation', m.father_occupation, 'mother_name', m.mother_name,
                           'mother_occupation', m.mother_occupation, 'siblings', m.siblings,
                           'phone_number', m.phone_number, 'email', m.email,
                           'whatsapp_number', m.whatsapp_number, 'is_contact_visible', m.is_contact_visible
                       ) FROM marriage_profiles m WHERE m.news_id = n.id) as marriage_details
                FROM news n 
                WHERE n.id = $1
            `, [news.id]);
            return res.status(201).json(fullNewsResult.rows[0]);
        }

        res.status(201).json(news);
    } catch (error) {
        console.error('Error inserting news:', error);
        res.status(500).json({ error: 'Failed to create news', details: error.message });
    }
});

app.put('/api/news/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const body = req.body;
        const marriage_details = body.marriage_details;
        delete body.marriage_details; // Remove from news table updates

        const keys = Object.keys(body);
        if (keys.length === 0 && !marriage_details) return res.status(400).json({ error: 'No fields to update' });

        if (keys.length > 0) {
            const setClause = keys.map((k, i) => `"${k}" = $${i + 1}`).join(', ');
            const values = Object.values(body);
            values.push(id);
            const { rows: updatedRows } = await db.query(`UPDATE news SET ${setClause} WHERE id = $${values.length} RETURNING *`, values);

            // Trigger Notification if Status changed to Published
            if (updatedRows.length > 0 && body.status === 'published') {
                const updatedNews = updatedRows[0];
                sendPushNotification(
                    updatedNews.is_breaking ? '🚨 BREAKING NEWS' : 'New Update',
                    updatedNews.title,
                    updatedNews.id
                );
            }
        }

        if (marriage_details) {
            console.log('Processing marriage details update for news:', id);
            const m = marriage_details;
            // Use ON CONFLICT to insert or update marriage profile
            const mQuery = `
                INSERT INTO marriage_profiles (
                    news_id, full_name, gender, date_of_birth, age, profile_photo, 
                    location, native_place, religion, caste, sub_caste, mother_tongue, 
                    highest_education, college_name, occupation, company_name, annual_income, 
                    father_name, father_occupation, mother_name, mother_occupation, siblings, 
                    phone_number, email, whatsapp_number, is_contact_visible
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)
                ON CONFLICT (news_id) DO UPDATE SET
                    full_name = EXCLUDED.full_name, gender = EXCLUDED.gender, date_of_birth = EXCLUDED.date_of_birth,
                    age = EXCLUDED.age, profile_photo = EXCLUDED.profile_photo, location = EXCLUDED.location,
                    native_place = EXCLUDED.native_place, religion = EXCLUDED.religion, caste = EXCLUDED.caste,
                    sub_caste = EXCLUDED.sub_caste, mother_tongue = EXCLUDED.mother_tongue,
                    highest_education = EXCLUDED.highest_education, college_name = EXCLUDED.college_name,
                    occupation = EXCLUDED.occupation, company_name = EXCLUDED.company_name,
                    annual_income = EXCLUDED.annual_income, father_name = EXCLUDED.father_name,
                    father_occupation = EXCLUDED.father_occupation, mother_name = EXCLUDED.mother_name,
                    mother_occupation = EXCLUDED.mother_occupation, siblings = EXCLUDED.siblings,
                    phone_number = EXCLUDED.phone_number, email = EXCLUDED.email,
                    whatsapp_number = EXCLUDED.whatsapp_number, is_contact_visible = EXCLUDED.is_contact_visible
            `;
            const mValues = [
                id,
                m.full_name ?? null,
                m.gender ?? null,
                m.date_of_birth ?? null,
                m.age ? parseInt(m.age) : null,
                m.profile_photo ?? null,
                m.location ?? null,
                m.native_place ?? null,
                m.religion ?? null,
                m.caste ?? null,
                m.sub_caste ?? null,
                m.mother_tongue ?? null,
                m.highest_education ?? null,
                m.college_name ?? null,
                m.occupation ?? null,
                m.company_name ?? null,
                m.annual_income ?? null,
                m.father_name ?? null,
                m.father_occupation ?? null,
                m.mother_name ?? null,
                m.mother_occupation ?? null,
                m.siblings ?? null,
                m.phone_number ?? null,
                m.email ?? null,
                m.whatsapp_number ?? null,
                m.is_contact_visible === true || m.is_contact_visible === 'true'
            ];
            await db.query(mQuery, mValues);
        }

        // Re-fetch and return the full updated news record
        const fullNewsResult = await db.query(`
            SELECT n.*, 
                   (SELECT json_build_object(
                       'full_name', m.full_name, 'gender', m.gender, 'date_of_birth', m.date_of_birth,
                       'age', m.age, 'profile_photo', m.profile_photo, 'location', m.location,
                       'native_place', m.native_place, 'religion', m.religion, 'caste', m.caste,
                       'sub_caste', m.sub_caste, 'mother_tongue', m.mother_tongue,
                       'highest_education', m.highest_education, 'college_name', m.college_name,
                       'occupation', m.occupation, 'company_name', m.company_name,
                       'annual_income', m.annual_income, 'father_name', m.father_name,
                       'father_occupation', m.father_occupation, 'mother_name', m.mother_name,
                       'mother_occupation', m.mother_occupation, 'siblings', m.siblings,
                       'phone_number', m.phone_number, 'email', m.email,
                       'whatsapp_number', m.whatsapp_number, 'is_contact_visible', m.is_contact_visible
                   ) FROM marriage_profiles m WHERE m.news_id = n.id) as marriage_details
            FROM news n 
            WHERE n.id = $1
        `, [id]);

        if (fullNewsResult.rows.length === 0) {
            return res.status(404).json({ error: 'News not found after update' });
        }
        res.json(fullNewsResult.rows[0]);
    } catch (error) {
        console.error('Error updating news (Detailed):', error);
        res.status(500).json({ error: 'Failed to update news: ' + error.message });
    }
});

app.delete('/api/news/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('DELETE FROM news WHERE id = $1', [id]);
        res.status(204).send();
    } catch (error) {
        console.error('Error deleting news:', error);
        res.status(500).json({ error: 'Failed to delete news' });
    }
});

// ==========================================
// MIGRATED ROUTES: SHORTS
// ==========================================
app.get('/api/shorts', async (req, res) => {
    try {
        const { district, role, status } = req.query;
        let query = 'SELECT * FROM shorts';
        let params = [];
        let conditions = [];

        // Role-based visibility
        if (role === 'super_admin') {
            if (status && status !== 'all') {
                conditions.push(`status = $${params.length + 1}`);
                params.push(status);
            }
        } else {
            // Mobile app and Reporters see published by default
            conditions.push(`status = $${params.length + 1}`);
            params.push('published');
        }

        // District filtering
        if (district) {
            conditions.push(`area = $${params.length + 1}`);
            params.push(district);
        }

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' AND ');
        }

        query += ' ORDER BY timestamp DESC';
        const { rows } = await db.query(query, params);
        res.json(rows);
    } catch (error) {
        console.error('Error fetching shorts:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/shorts', async (req, res) => {
    try {
        const { title, video_url, videoUrl, duration, area, author, status } = req.body;
        const finalVideoUrl = video_url || videoUrl;
        const query = `
      INSERT INTO shorts(title, video_url, duration, area, author, status)
        VALUES($1, $2, $3, $4, $5, $6)
        RETURNING *;
        `;
        const { rows } = await db.query(query, [title, finalVideoUrl, duration, area || 'General', author || 'Admin', status || 'pending']);
        const short = rows[0];
        res.status(201).json(short);

        // Trigger Notification if Published
        if (short.status === 'published') {
            sendPushNotification('ðŸŽ¥ New Video Highlight', short.title, short.id, 'short');
        }
    } catch (error) {
        console.error('Error inserting short:', error);
        res.status(500).json({ error: 'Failed to create short' });
    }
});

app.put('/api/shorts/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const keys = Object.keys(updates);
        if (keys.length === 0) return res.status(400).json({ error: 'No fields to update' });

        const setClause = keys.map((k, i) => `"${k}" = $${i + 1} `).join(', ');
        const values = Object.values(updates);
        values.push(id);

        const query = `UPDATE shorts SET ${setClause} WHERE id = $${values.length} RETURNING *; `;
        const { rows } = await db.query(query, values);
        if (rows.length === 0) return res.status(404).json({ error: 'Short not found' });
        const updatedShort = rows[0];
        res.json(updatedShort);

        // Trigger Notification if Status changed to Published
        if (updates.status === 'published') {
            sendPushNotification('ðŸŽ¥ New Video Highlight', updatedShort.title, updatedShort.id, 'short');
        }
    } catch (error) {
        console.error('Error updating short:', error);
        res.status(500).json({ error: 'Failed to update short' });
    }
});

app.delete('/api/shorts/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('DELETE FROM shorts WHERE id = $1', [id]);
        res.status(204).send();
    } catch (error) {
        console.error('Error deleting short:', error);
        res.status(500).json({ error: 'Failed to delete short' });
    }
});

// ==========================================
// MIGRATED ROUTES: ADVERTISEMENTS
// ==========================================
app.get('/api/advertisements', async (req, res) => {
    try {
        const { status } = req.query;
        let query = 'SELECT * FROM advertisements';
        let params = [];

        // Default to published for mobile apps
        const finalStatus = status || 'published';
        if (finalStatus !== 'all') {
            query += ' WHERE status = $1';
            params.push(finalStatus);
        }

        query += ' ORDER BY timestamp DESC';
        const { rows } = await db.query(query, params);
        res.json(rows);
    } catch (error) {
        console.error('Error fetching ads:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/advertisements', async (req, res) => {
    try {
        const { media_url, interval_minutes, display_interval, click_url, is_active, status } = req.body;
        const query = `
      INSERT INTO advertisements(media_url, interval_minutes, display_interval, click_url, is_active, status)
        VALUES($1, $2, $3, $4, $5, $6)
        RETURNING *;
        `;
        const { rows } = await db.query(query, [media_url, interval_minutes, display_interval || 4, click_url, is_active, status || 'published']);
        res.status(201).json(rows[0]);
    } catch (error) {
        console.error('Error inserting ad:', error);
        res.status(500).json({ error: 'Failed to create ad' });
    }
});

app.put('/api/advertisements/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const keys = Object.keys(updates);
        if (keys.length === 0) return res.status(400).json({ error: 'No fields to update' });

        const setClause = keys.map((k, i) => `"${k}" = $${i + 1} `).join(', ');
        const values = Object.values(updates);
        values.push(id);

        const query = `UPDATE advertisements SET ${setClause} WHERE id = $${values.length} RETURNING *; `;
        const { rows } = await db.query(query, values);
        if (rows.length === 0) return res.status(404).json({ error: 'Ad not found' });
        res.json(rows[0]);
    } catch (error) {
        console.error('Error updating ad:', error);
        res.status(500).json({ error: 'Failed to update ad' });
    }
});

app.delete('/api/advertisements/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('DELETE FROM advertisements WHERE id = $1', [id]);
        res.status(204).send();
    } catch (error) {
        console.error('Error deleting ad:', error);
        res.status(500).json({ error: 'Failed to delete ad' });
    }
});

// ==========================================
// MIGRATED ROUTES: COMMENTS & LIKES
// ==========================================
// --- Shorts Comments ---
app.get('/api/shorts/:id/comments', async (req, res) => {
    try {
        const { id } = req.params;
        const query = 'SELECT * FROM shorts_comments WHERE short_id = $1 ORDER BY created_at DESC';
        const { rows } = await db.query(query, [id]);
        res.json(rows);
    } catch (error) {
        console.error('Error fetching short comments:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/shorts/comments', async (req, res) => {
    try {
        const { short_id, user_id, user_name, comment_text } = req.body;
        const query = `
      INSERT INTO shorts_comments(short_id, user_id, user_name, comment_text)
        VALUES($1, $2, $3, $4)
        RETURNING *;
        `;
        const { rows } = await db.query(query, [short_id, user_id, user_name, comment_text]);
        await db.query('UPDATE shorts SET comments_count = comments_count + 1 WHERE id = $1', [short_id]);
        res.status(201).json(rows[0]);
    } catch (error) {
        console.error('Error inserting short comment:', error);
        res.status(500).json({ error: 'Failed to add comment' });
    }
});

app.delete('/api/shorts/comments/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { rows } = await db.query('DELETE FROM shorts_comments WHERE id = $1 RETURNING short_id', [id]);
        if (rows.length > 0) {
            const shortId = rows[0].short_id;
            await db.query('UPDATE shorts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = $1', [shortId]);
        }
        res.status(204).send();
    } catch (error) {
        console.error('Error deleting short comment:', error);
        res.status(500).json({ error: 'Failed to delete comment' });
    }
});

// --- News Comments ---
app.get('/api/news/:id/comments', async (req, res) => {
    try {
        const { id } = req.params;
        const query = 'SELECT * FROM news_comments WHERE news_id = $1 ORDER BY created_at DESC';
        const { rows } = await db.query(query, [id]);
        res.json(rows);
    } catch (error) {
        console.error('Error fetching news comments:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/news/comments', async (req, res) => {
    try {
        const { news_id, user_id, user_name, comment_text } = req.body;
        const query = `
      INSERT INTO news_comments(news_id, user_id, user_name, comment_text)
        VALUES($1, $2, $3, $4)
        RETURNING *;
        `;
        const { rows } = await db.query(query, [news_id, user_id, user_name, comment_text]);
        await db.query('UPDATE news SET comments_count = comments_count + 1 WHERE id = $1', [news_id]);
        res.status(201).json(rows[0]);
    } catch (error) {
        console.error('Error inserting news comment:', error);
        res.status(500).json({ error: 'Failed to add comment' });
    }
});

app.delete('/api/news/comments/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { rows } = await db.query('DELETE FROM news_comments WHERE id = $1 RETURNING news_id', [id]);
        if (rows.length > 0) {
            const newsId = rows[0].news_id;
            await db.query('UPDATE news SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = $1', [newsId]);
        }
        res.status(204).send();
    } catch (error) {
        console.error('Error deleting news comment:', error);
        res.status(500).json({ error: 'Failed to delete comment' });
    }
});

// Likes logic
app.post('/api/news/:id/like', async (req, res) => {
    try {
        const { id } = req.params;
        const { user_id, action } = req.body; // action: 'like' or 'unlike'

        if (action === 'like') {
            await db.query('INSERT INTO news_likes (news_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [id, user_id]);
            await db.query('SELECT increment_news_likes($1)', [id]);
        } else {
            await db.query('DELETE FROM news_likes WHERE news_id = $1 AND user_id = $2', [id, user_id]);
            await db.query('SELECT decrement_news_likes($1)', [id]);
        }

        const { rows } = await db.query('SELECT likes FROM news WHERE id = $1', [id]);
        res.json({ likes: rows[0].likes });
    } catch (error) {
        console.error('Error modifying news likes:', error);
        res.status(500).json({ error: 'Failed to process like' });
    }
});

app.post('/api/shorts/:id/like', async (req, res) => {
    try {
        const { id } = req.params;
        const { user_id, action } = req.body;

        if (action === 'like') {
            await db.query('INSERT INTO shorts_likes (short_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [id, user_id]);
            await db.query('SELECT increment_shorts_likes($1)', [id]);
        } else {
            await db.query('DELETE FROM shorts_likes WHERE short_id = $1 AND user_id = $2', [id, user_id]);
            await db.query('SELECT decrement_shorts_likes($1)', [id]);
        }

        const { rows } = await db.query('SELECT likes FROM shorts WHERE id = $1', [id]);
        res.json({ likes: rows[0] ? rows[0].likes : 0 });
    } catch (error) {
        console.error('Error modifying short likes:', error);
        res.status(500).json({ error: 'Failed to process like' });
    }
});

// ==========================================
// MIGRATED ROUTES: STORAGE
// ==========================================
app.get('/api/user/:id/stats', async (req, res) => {
    try {
        const { id } = req.params;

        // 1. Get comments count from shorts_comments
        const commentsResult = await db.query('SELECT COUNT(*) as count FROM shorts_comments WHERE user_id = $1', [id]);
        const commentsCount = parseInt(commentsResult.rows[0].count, 10) || 0;

        // 2. Notifications count: For now, return the number of news items added in the last 24 hours as available notifications.
        const newsResult = await db.query("SELECT COUNT(*) as count FROM news WHERE created_at >= NOW() - INTERVAL '24 HOURS'");
        const notificationsCount = parseInt(newsResult.rows[0].count, 10) || 0;

        res.json({ commentsCount, notificationsCount });
    } catch (error) {
        console.error('Error fetching user stats:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.get('/api/user/:id/likes', async (req, res) => {
    try {
        const { id } = req.params;

        const newsLikes = await db.query('SELECT news_id FROM news_likes WHERE user_id = $1', [id]);
        const shortsLikes = await db.query('SELECT short_id FROM shorts_likes WHERE user_id = $1', [id]);

        res.json({
            news: newsLikes.rows.map(row => row.news_id),
            shorts: shortsLikes.rows.map(row => row.short_id)
        });
    } catch (error) {
        console.error('Error fetching user likes:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Robust upload route supporting multiple field names
app.post('/api/upload', (req, res, next) => {
    console.log(`[Upload DEBUG] Request received from ${req.ip} - Content-Length: ${req.headers['content-length']}`);
    next();
}, upload.any(), async (req, res) => {
    console.log('[Upload DEBUG] Multer parsing complete');

    try {
        const uploadedFile = (req.files && req.files.length > 0) ? req.files[0] : null;

        if (!uploadedFile) {
            console.warn('[Upload] No file found in request');
            return res.status(400).json({ error: 'à°Žà°Ÿà± à°µà°‚à°Ÿà°¿ à°«à±ˆà°²à±  à°…à°‚à°¦à°²à±‡à°¦à±  (No file received)' });
        }

        const fileName = uploadedFile.filename;
        const finalPath = path.join(uploadsDir, fileName);
        console.log(`[Upload DEBUG] 1. Saving locally to: ${finalPath}`);

        // Move from tmp to final uploads folder
        try {
            fs.renameSync(uploadedFile.path, finalPath);
            console.log('[Upload DEBUG] 2. renameSync successful');
        } catch (renameErr) {
            console.warn('[Upload DEBUG] renameSync failed, using copy fallback');
            try {
                fs.copyFileSync(uploadedFile.path, finalPath);
                console.log('[Upload DEBUG] 2b. copyFileSync successful');
                try { fs.unlinkSync(uploadedFile.path); } catch (e) {}
            } catch (copyErr) {
                console.error('[Upload DEBUG] CRASH at copyFileSync:', copyErr.message);
                throw copyErr;
            }
        }

        const protocol = req.protocol;
        const host = req.get('host');
        const localPublicUrl = `${protocol}://${host}/api/uploads/${fileName}`;
        let publicUrl = localPublicUrl;

        // 4. Try R2 if enabled (Temporarily disabled to fix 502 crash)
        const canUseR2 = false; 
        if (canUseR2 && hasR2Config()) {
            try {
                console.log('[Upload DEBUG] 4. R2 Config found, starting upload...');
                const s3 = getS3Client();
                if (!s3) throw new Error('S3 client not initialized');

                const stats = fs.statSync(finalPath);
                const isLargeFile = stats.size > 5 * 1024 * 1024; // > 5MB
                
                let uploadBody;
                if (isLargeFile) {
                    console.log(`[Upload DEBUG] Large file detected (${(stats.size/1024/1024).toFixed(1)}MB), using stream.`);
                    uploadBody = fs.createReadStream(finalPath);
                } else {
                    console.log(`[Upload DEBUG] Small file detected (${(stats.size/1024).toFixed(1)}KB), using buffer.`);
                    uploadBody = fs.readFileSync(finalPath);
                }
                
                await s3.send(new PutObjectCommand({
                    Bucket: process.env.R2_BUCKET_NAME || 'samanyudu-media',
                    Key: fileName,
                    Body: uploadBody,
                    ContentType: uploadedFile.mimetype,
                }));

                if (process.env.R2_PUBLIC_DOMAIN) {
                    publicUrl = `https://${process.env.R2_PUBLIC_DOMAIN}/${fileName}`;
                }
                console.log(`[Upload DEBUG] 5. R2 Success: ${fileName}`);
            } catch (r2Error) {
                console.error('[Upload DEBUG] R2 Error (falling back to local):', r2Error.message || r2Error);
                // Fallback is already handled by publicUrl defaulting to localPublicUrl
            }
        } else {
            console.log('[Upload DEBUG] 4. R2 skipped (using local storage)');
        }



        console.log(`[Upload] Success: ${fileName} -> ${publicUrl}`);
        res.json({ url: publicUrl });

    } catch (err) {
        console.error('[Upload] Critical Error:', err);
        res.status(500).json({ error: 'File processing failed', details: err.message });
    }
});



// ==========================================
// SAVED ITEMS
// ==========================================
app.get('/api/user/:id/saved', async (req, res) => {
    try {
        const { id } = req.params;
        const { rows } = await db.query('SELECT item_id, item_type FROM saved_items WHERE user_id = $1', [id]);

        const news = rows.filter(r => r.item_type === 'news').map(r => r.item_id);
        const shorts = rows.filter(r => r.item_type === 'shorts').map(r => r.item_id);

        res.json({ news, shorts });
    } catch (error) {
        console.error('Error fetching saved items:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/user/:id/save', async (req, res) => {
    try {
        const { id } = req.params;
        const { item_id, item_type, action } = req.body; // action: 'save' or 'unsave'

        if (action === 'save') {
            await db.query('INSERT INTO saved_items (user_id, item_id, item_type) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING', [id, item_id, item_type || 'news']);
        } else {
            await db.query('DELETE FROM saved_items WHERE user_id = $1 AND item_id = $2 AND item_type = $3', [id, item_id, item_type || 'news']);
        }
        res.json({ success: true });
    } catch (error) {
        console.error('Error modifying saved items:', error);
        res.status(500).json({ error: 'Failed to process save' });
    }
});

app.post('/api/user/:id/sync-saved', async (req, res) => {
    try {
        const { id } = req.params;
        const { news, shorts } = req.body;

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
            [firstName, lastName, name, email, await bcrypt.hash(password.trim(), 10)]
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

        const subject = type === 'reset' ? 'Password Reset Verification' : 'Your Signup Verification Code';
        const html = type === 'reset'
            ? `<h3>Password Reset Code: <b>${otp}</b></h3><p>Enter this code to reset your password. It will expire in 10 minutes.</p>`
            : `<h3>Your Verification Code is: <b>${otp}</b></h3><p>This code will expire in 10 minutes.</p>`;

        if (typeof resend !== 'undefined' && resend) {
            try {
                await resend.emails.send({
                    from: 'Samanyudu TV <noreply@samanyudutv.in>',
                    to: email,
                    subject: subject,
                    html: html
                });
                return res.json({ success: true, message: 'OTP sent to email', type });
            } catch (err) {
                console.error('Resend email failed:', err.message);
            }
        }

        if (typeof transporter !== 'undefined' && transporter) {
            try {
                await transporter.sendMail({
                    from: '"Samanyudu TV" <' + (process.env.SMTP_FROM || process.env.SMTP_USER) + '>',
                    to: email,
                    subject: subject,
                    html: html
                });
                return res.json({ success: true, message: 'OTP sent to email via SMTP', type });
            } catch (err) {
                console.error('SMTP email failed:', err.message);
                throw err;
            }
        }

        return res.status(400).json({ error: 'Email service not configured' });
    } catch (err) {
        console.error('Error sending email OTP:', err);
        res.status(500).json({ error: 'Failed to send verification email' });
    }
});

app.post('/api/auth/reset-password-email', async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;
        if (!email || !otp || !newPassword) {
            return res.status(400).json({ error: 'Email, OTP and new password are required' });
        }

        const storedData = emailOtpStore.get(email);
        if (!storedData || storedData.expires < Date.now()) {
            return res.status(400).json({ error: 'Invalid or expired OTP' });
        }

        if (storedData.otp !== String(otp).trim() || storedData.type !== 'reset') {
            return res.status(400).json({ error: 'Invalid OTP' });
        }

        const { rowCount } = await db.query('UPDATE users SET password = $1 WHERE email = $2', [await bcrypt.hash(newPassword.trim(), 10), email]);

        if (rowCount === 0) {
            return res.status(404).json({ error: 'Account not found with this email' });
        }

        emailOtpStore.delete(email);
        res.json({ success: true, message: 'Password reset successfully' });
    } catch (err) {
        console.error("Error resetting password via email:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});


// Image Proxy for CanvasKit
const https = require('https');
app.get('/api/image-proxy', (req, res) => {
    const imageUrl = req.query.url;
    if (!imageUrl) return res.status(400).send('URL required');
    https.get(imageUrl, (response) => {
        if (response.headers['content-type']) {
            res.setHeader('Content-Type', response.headers['content-type']);
        }
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Cache-Control', 'public, max-age=31536000');
        response.pipe(res);
    }).on('error', (e) => res.status(500).send(e.message));
});

// Settings Routes
app.get('/api/settings', async (req, res) => {
    try {
        const { rows } = await db.query('SELECT * FROM app_settings');
        const settings = {};
        rows.forEach(r => settings[r.key] = r.value);
        res.json(settings);
    } catch (error) {
        console.error('Fetch settings error:', error);
        res.status(500).json({ error: 'Failed to fetch settings' });
    }
});

app.post('/api/settings', async (req, res) => {
    try {
        const { key, value } = req.body;
        if (!key) return res.status(400).json({ error: 'Key is required' });
        await db.query('INSERT INTO app_settings (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = $2', [key, JSON.stringify(value)]);
        res.json({ success: true });
    } catch (error) {
        console.error('Update settings error:', error);
        res.status(500).json({ error: 'Failed to update settings' });
    }
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`ðŸš€ API Backend running on http://0.0.0.0:${port}`);
});


// Auto-initialize settings table
async function init() {
    try {
        await db.query('CREATE TABLE IF NOT EXISTS app_settings (key VARCHAR PRIMARY KEY, value JSONB)');
        await db.query("INSERT INTO app_settings (key, value) VALUES ('maintenance_mode', 'false') ON CONFLICT (key) DO NOTHING");
        await db.query("INSERT INTO app_settings (key, value) VALUES ('live_youtube_url', '\"\"') ON CONFLICT (key) DO NOTHING");
        console.log('âœ… Settings table initialized');
    } catch (err) {
        console.error('âŒ Failed to initialize settings table:', err.message);
    }
}

init();

// Keep alive
setInterval(() => { }, 60000);



