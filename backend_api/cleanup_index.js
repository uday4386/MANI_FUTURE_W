const fs = require('fs');
const path = require('path');
const indexPath = path.join(__dirname, 'index.js');
let content = fs.readFileSync(indexPath, 'utf8');

// The logic is to Remove the block that starts with line 249 and ends before line 271 logic
const lines = content.split('\n');
const fixedLines = [
    ...lines.slice(0, 248),
    ...lines.slice(269)
];

fs.writeFileSync(indexPath, fixedLines.join('\n'));
console.log('✅ index.js cleaned up');
