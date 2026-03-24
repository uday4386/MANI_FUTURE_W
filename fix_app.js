const fs = require('fs');
const filePath = 'c:\\Users\\savya\\OneDrive\\Documents\\Samanyudu TV\\src\\App.tsx';
let content = fs.readFileSync(filePath, 'utf8');

// Find the first correct end of SettingsView
const target = "onChange={handleToggleMaintenance}\n                  />\n                  <div className=\"w-11 h-6 bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:translate-x-full after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-yellow-500\"></div>\n                </label>\n              </div>\n            ) : (\n              <div className=\"p-4 bg-slate-900/30 rounded-lg border border-slate-700/50 text-slate-500 text-sm italic\">\n                Maintenance settings are only available to Super Admins.\n              </div>\n            )}\n          </div>\n        </div>\n      </div>\n    </div>\n  );\n}";

// Actually, let's just find the broken pattern and replace it
const brokenMarker = "  );\n}: { user: any }) => {";
const componentEnd = "};\n\nconst useItemInteractions";

const brokenStartIdx = content.indexOf(brokenMarker);
const componentEndIdx = content.indexOf(componentEnd);

if (brokenStartIdx !== -1 && componentEndIdx !== -1) {
    // Replace from the broken marker to the end of the duplicated component
    const replacement = "  );\n};\n";
    content = content.substring(0, brokenStartIdx) + replacement + content.substring(componentEndIdx + 2);
    fs.writeFileSync(filePath, content, 'utf8');
    console.log("Fixed App.tsx duplication successfully");
} else {
    console.log("Could not find markers", { brokenStartIdx, componentEndIdx });
}
