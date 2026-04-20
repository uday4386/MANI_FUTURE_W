require('dotenv').config();
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT),
    secure: process.env.SMTP_PORT == '465', // true for 465, false for 587
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
    },
    tls: {
        rejectUnauthorized: false
    }
});

async function testEmail() {
    try {
        console.log("Testing connection...");
        await transporter.verify();
        console.log("Connection verified!");

        const mailOptions = {
            from: process.env.SMTP_FROM,
            to: '22jk1a0599@gmail.com', // send to self
            subject: 'Test Email',
            text: 'This is a test email sent from Node.js'
        };

        const info = await transporter.sendMail(mailOptions);
        console.log("Email sent successfully: ", info.messageId);
    } catch (err) {
        console.error("Failed to send email: ", err);
    }
}

testEmail();
