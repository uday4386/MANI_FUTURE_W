const fs = require('fs');
const filePath = 'c:\\Users\\savya\\OneDrive\\Documents\\Samanyudu TV\\src\\App.tsx';
let lines = fs.readFileSync(filePath, 'utf8').split('\n');

// Find the line with the broken syntax
const brokenLineIdx = lines.findIndex(l => l.includes('): { user: any }) => {') && l.includes(');'));
// Wait, the line number in the error was 425.
// Let's find the first line that matches the broken pattern.
const pattern = "}: { user: any }) => {";
const line425Idx = lines.findIndex(l => l.includes(pattern));

if (line425Idx !== -1) {
    // We found the broken start. 
    // Now find the end of this duplicated component (lines 425 to 550 roughly).
    // The next component starts with "const useItemInteractions".
    const nextCompIdx = lines.findIndex(l => l.includes("const useItemInteractions"));

    if (nextCompIdx !== -1) {
        // Remove lines from line425Idx up to nextCompIdx
        // But we need to add a "};" to close the previous valid component at line424.
        lines.splice(line425Idx, nextCompIdx - line425Idx, "};", "");
        fs.writeFileSync(filePath, lines.join('\n'), 'utf8');
        console.log("Successfully patched App.tsx");
    } else {
        console.log("Could not find start of next interaction");
    }
} else {
    console.log("Could not find broken pattern at line 425 source");
}
