
$apiFilePath = "c:\Users\savya\OneDrive\Documents\Samanyudu TV\Mobile_App\Samanyudu-News_App\lib\services\api_service.dart"
# First, revert the previous bad append if any (restore based on line count - assuming we added 20 lines)
$apiContent = Get-Content $apiFilePath
if ($apiContent[-1] -eq "}" -and $apiContent[-12] -match "parse") {
    $apiContent = $apiContent[0..($apiContent.Length-21)]
} else {
    $apiContent = $apiContent[0..($apiContent.Length-2)]
}

$apiNewMethod = @"

  static Future<Map<String, dynamic>> registerWithFirebase({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    final response = await http.post(
      Uri.parse('`$baseUrl/auth/register-firebase'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'uid': uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
      }),
    );
    return json.decode(response.body);
  }
}
"@
Set-Content $apiFilePath ($apiContent + $apiNewMethod)

$indexFilePath = "c:\Users\savya\OneDrive\Documents\Samanyudu TV\backend_api\index.js"
$indexContent = Get-Content $indexFilePath -Raw
# If it already has the clean version without $, remove it first to avoid double append
$indexContent = $indexContent -replace "// 2b. Register/Sync Firebase User.*Failed to sync user.*}\);", ""

$firebaseRoute = @"

// 2b. Register/Sync Firebase User
app.post('/api/auth/register-firebase', async (req, res) => {
    try {
        const { uid, email, firstName, lastName } = req.body;
        if (!uid || !email || !firstName || !lastName) return res.status(400).json({ error: 'All fields are required' });
        const { rows } = await db.query('SELECT * FROM users WHERE email = `$1', [email]);
        let user;
        if (rows.length > 0) {
            const updateResult = await db.query('UPDATE users SET first_name = `$1, last_name = `$2 WHERE email = `$3 RETURNING *', [firstName, lastName, email]);
            user = updateResult.rows[0];
        } else {
            const insertResult = await db.query('INSERT INTO users (email, first_name, last_name, name) VALUES (`$1, `$2, `$3, `$4) RETURNING *', [email, firstName, lastName, ``${firstName} ``${lastName}``.trim()]);
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
if ($indexContent -like "*register-firebase*") {
    # Already contains it (maybe the bad version), just replace the bad part if searchStr still exists
    $indexContent = $indexContent.Replace($searchStr, $firebaseRoute + $searchStr)
} else {
    $indexContent = $indexContent.Replace($searchStr, $firebaseRoute + $searchStr)
}
Set-Content $indexFilePath $indexContent
