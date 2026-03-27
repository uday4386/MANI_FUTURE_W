const db = require('./db');
const fetch = require('node-fetch');

const BASE_URL = 'http://localhost:5000/api';

async function test() {
    try {
        console.log('1. Posting news with status "pending"...');
        const postRes = await fetch(`${BASE_URL}/news`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                title: 'Visibility Test News',
                description: 'Should not be visible',
                area: 'Test',
                type: 'Test',
                status: 'pending'
            })
        });
        const postData = await postRes.json();
        const newsId = postData.id;
        console.log('Created ID:', newsId, 'Status:', postData.status);

        console.log('\n2. Fetching news (simulating mobile app)...');
        const getRes = await fetch(`${BASE_URL}/news`);
        const getData = await getRes.json();
        
        const found = getData.some(n => n.id === newsId);
        console.log('Is visible in mobile feed?:', found);

        if (found) {
            console.log('ERROR: Pending news IS visible in mobile feed!');
            // Show the status of the item in the feed
            const item = getData.find(n => n.id === newsId);
            console.log('Item in feed status:', item.status);
        } else {
            console.log('SUCCESS: Pending news is HIDDEN from mobile feed.');
        }

        console.log('\n3. Cleaning up...');
        await db.query('DELETE FROM news WHERE id = $1', [newsId]);
        console.log('Cleanup done.');

    } catch (err) {
        console.error(err);
    }
}

test();
