const fs = require('fs');
const path = require('path');
const indexPath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(indexPath, 'utf8');

// Update Resend initialization to be conditional or at least not crash
const oldInit = "const resend = new Resend(process.env.RESEND_API_KEY);";
const newInit = "const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;";

if (content.indexOf(oldInit) !== -1) {
    content = content.replace(oldInit, newInit);
}

// Also update the route to check for resend
const oldRouteStart = "console.log(`[Email Auth] Sending email via Resend to: ${email}`);\n        \n        const { data, error } = await resend.emails.send({";
const newRouteStart = "if (!resend) {\n            console.error('[Resend] API Key missing');\n            throw new Error('Email service not configured');\n        }\n        console.log(`[Email Auth] Sending email via Resend to: ${email}`);\n        const { data, error } = await resend.emails.send({";

if (content.indexOf(oldRouteStart) !== -1) {
    content = content.replace(oldRouteStart, newRouteStart);
}

fs.writeFileSync(indexPath, content);
console.log('✅ Resend initialization made optional');
