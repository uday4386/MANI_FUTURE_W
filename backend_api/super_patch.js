
const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(filePath, 'utf-8');

// 1. REWRITE THE ADD REPORTER (POST)
const postStart = "app.post('/api/admin/reporters', async (req, res) => {";
const postEnd = "});"; // End of that block
const postNewInner = `
    try {
        const { email, password, name, state, district } = req.body;
        const hashedPassword = await bcrypt.hash(password, 10);
        const query = 'INSERT INTO admin_users (email, password, name, state, district, role) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, email, name, state, district';
        const { rows } = await db.query(query, [email, hashedPassword, name, state, district, 'sub_admin']);
        res.status(201).json(rows[0]);
    } catch (error) {
        if (error.code === '23505') return res.status(400).json({ error: 'Email already exists' });
        res.status(500).json({ error: 'Failed to create reporter' });
    }
`;

// 2. REWRITE THE EDIT REPORTER (PUT)
const putStart = "app.put('/api/admin/reporters/:id', async (req, res) => {";
const putNewInner = `
    try {
        const { id } = req.params;
        const updates = { ...req.body };
        if (updates.password) {
            updates.password = await bcrypt.hash(updates.password, 10);
        }
        const keys = Object.keys(updates);
        if (keys.length === 0) return res.status(400).json({ error: 'No fields to update' });
        const setClause = keys.map((k, i) => \`"\${k}" = $\${i + 1}\`).join(', ');
        const values = Object.values(updates);
        values.push(id);
        const query = \`UPDATE admin_users SET \${setClause} WHERE id = $\${values.length} RETURNING id, email, password, name, state, district, role;\`;
        const { rows } = await db.query(query, values);
        if (rows.length === 0) return res.status(404).json({ error: 'Reporter not found' });
        res.json(rows[0]);
    } catch (error) {
        console.error('Error updating reporter:', error);
        res.status(500).json({ error: 'Failed to update reporter' });
    }
`;

// Surgical replacement using regex to find the blocks even with different formatting
const postRegex = /app\.post\('\/api\/admin\/reporters'[\s\S]*?res\.status\(500\)[\s\S]*?\}\);/;
const putRegex = /app\.put\('\/api\/admin\/reporters\/:id'[\s\S]*?res\.status\(500\)[\s\S]*?\}\);/;

content = content.replace(postRegex, `app.post('/api/admin/reporters', async (req, res) => {${postNewInner}});`);
content = content.replace(putRegex, `app.put('/api/admin/reporters/:id', async (req, res) => {${putNewInner}});`);

fs.writeFileSync(filePath, content);
console.log('💎 SUPER PATCH COMPLETE. The converter is now permanently installed.');
process.exit(0);
