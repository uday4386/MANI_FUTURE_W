
$indexFilePath = "c:\Users\savya\OneDrive\Documents\Samanyudu TV\backend_api\index.js"
$content = Get-Content $indexFilePath -Raw

# Remove all occurrences of the firebase-register route that might have been added
$pattern = '(?s)// 2b\. Register/Sync Firebase User.*?}\);'
$content = $content -replace $pattern, ""

# Clean up any leftover empty lines
while ($content -match "\n\n\n") {
    $content = $content -replace "\n\n\n", "`n`n"
}

$firebaseRoute = @"

// 2b. Register/Sync Firebase User
app.post('/api/auth/register-firebase', async (req, res) => {
    try {
        const { uid, email, firstName, lastName } = req.body;
        if (!uid || !email || !firstName || !lastName) return res.status(400).json({ error: 'All fields are required' });
        const { rows } = await db.query('SELECT * FROM users WHERE email = `$1', [email]);
        let user;
        if (rows.length > 0) {
            const updateResult = await db.query('UPDATE users SET first_name = `$1, last_name = `$2, firebase_uid = `$3 WHERE email = `$4 RETURNING *', [firstName, lastName, uid, email]);
            user = updateResult.rows[0];
        } else {
            const insertResult = await db.query('INSERT INTO users (email, first_name, last_name, name, firebase_uid) VALUES (`$1, `$2, `$3, `$4, `$5) RETURNING *', [email, firstName, lastName, ``${firstName} ``${lastName}``.trim(), uid]);
            user = insertResult.rows[0];
        }
        res.json({ success: true, user: { id: user.id, email: user.email, name: user.name || ``${user.first_name} ``${user.last_name}``.trim() } });
    } catch (err) {
        console.error("Error syncing Firebase user:", err);
        res.status(500).json({ error: 'Failed to sync user' });
    }
});

"@

$searchStr = "// 3. Login with Email and Password"
$content = $content.Replace($searchStr, $firebaseRoute + $searchStr)
Set-Content $indexFilePath $content
