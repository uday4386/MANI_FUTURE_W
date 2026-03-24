const fs = require('fs');
const path = require('path');

const filePath = 'c:\\Users\\savya\\OneDrive\\Documents\\Samanyudu TV\\src\\App.tsx';
let content = fs.readFileSync(filePath, 'utf8');

// 1. Add maintenance state
const statePattern = /const \[viewingMedia, setViewingMedia\] = useState<NewsItem \| ShortItem \| null>\(null\);/;
if (content.search(statePattern) === -1) {
    console.error("Pattern 1 not found");
    process.exit(1);
}
content = content.replace(statePattern,
    `const [viewingMedia, setViewingMedia] = useState<NewsItem | ShortItem | null>(null);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [isCheckingMaintenance, setIsCheckingMaintenance] = useState(true);`);

// 2. Add maintenance check useEffect
const authHandlingPattern = /\/\/ -- Auth Handling --/;
if (content.search(authHandlingPattern) === -1) {
    console.error("Pattern 2 not found");
    process.exit(1);
}
content = content.replace(authHandlingPattern,
    `useEffect(() => {
    const fetchMaintenance = async () => {
      try {
        const { enabled } = await api.getMaintenanceStatus();
        setMaintenanceMode(enabled);
      } catch (err) {
        console.warn("Maintenance check failed:", err);
      } finally {
        setIsCheckingMaintenance(false);
      }
    };
    fetchMaintenance();
    const interval = setInterval(fetchMaintenance, 60000);
    return () => clearInterval(interval);
  }, []);

  // -- Auth Handling --`);

// 3. Add blocking logic
const adminUserCheckPattern = /if \(!adminUser\) \{/;
if (content.search(adminUserCheckPattern) === -1) {
    console.error("Pattern 3 not found");
    process.exit(1);
}
content = content.replace(adminUserCheckPattern,
    `if (!adminUser) {
    return <LoginView onLogin={handleLogin} />;
  }

  if (maintenanceMode && adminUser.role === 'sub_admin') {
    return (
      <div className="fixed inset-0 bg-[#0f172a] z-[300] flex items-center justify-center p-6">
        <div className="bg-slate-900 p-8 rounded-2xl border border-slate-800 shadow-2xl max-w-md w-full text-center">
          <div className="w-20 h-20 bg-yellow-500/10 rounded-full flex items-center justify-center mx-auto mb-6">
            <Settings className="text-yellow-500 animate-spin-slow" size={40} />
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">System Maintenance</h2>
          <p className="text-slate-400 mb-8">
            The portal is currently under maintenance. District Reporter access has been temporarily restricted by the Super Admin.
          </p>
          <div className="space-y-4">
            <div className="p-4 bg-slate-800/50 rounded-lg border border-slate-700 text-xs text-slate-500">
              Please try again after some time or contact the main office for urgent updates.
            </div>
            <button
              onClick={handleLogout}
              className="w-full py-3 px-4 bg-slate-800 hover:bg-slate-700 text-white rounded-xl font-medium transition-colors border border-slate-700"
            >
              Sign Out
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (!adminUser) {`);

// 4. Update SettingsView (this is more complex, I'll use a simpler replace)
const settingsViewPattern = /const SettingsView = \(\{ user \}: \{ user: any \}\) => \{/;
if (content.search(settingsViewPattern) === -1) {
    console.error("Pattern 4 not found");
    process.exit(1);
}

// Overwrite SettingsView with the new implementation
const startIdx = content.indexOf('const SettingsView = ({ user }: { user: any }) => {');
const endMarker = '};';
let currentIdx = startIdx;
let bracketCount = 0;
let endIdx = -1;

for (let i = startIdx; i < content.length; i++) {
    if (content[i] === '{') bracketCount++;
    if (content[i] === '}') {
        bracketCount--;
        if (bracketCount === 0) {
            endIdx = i + 1;
            break;
        }
    }
}

if (endIdx === -1) {
    console.error("Could not find end of SettingsView");
    process.exit(1);
}

const newSettingsView = `const SettingsView = ({ user }: { user: any }) => {
  const [showPasswordForm, setShowPasswordForm] = useState(false);
  const [passwords, setPasswords] = useState({ current: '', new: '', confirm: '' });
  const [maintenance, setMaintenance] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const status = await api.getMaintenanceStatus();
        setMaintenance(status.enabled);
      } catch (err) {
        console.error("Failed to fetch settings:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchSettings();
  }, []);

  const handleToggleMaintenance = async () => {
    if (user.role !== 'super_admin') return;
    try {
      const newVal = !maintenance;
      await api.updateMaintenanceStatus(newVal);
      setMaintenance(newVal);
      toast.success(\`Maintenance mode \${newVal ? 'ENABLED' : 'DISABLED'}\`);
    } catch (err) {
      toast.error("Failed to update maintenance status");
    }
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    if (passwords.new !== passwords.confirm) {
      toast.error("New passwords don't match");
      return;
    }
    try {
      if (user.role === 'super_admin') {
         // Super admin password update logic if needed
      }
      await api.updateReporter(user.id, { password: passwords.new });
      toast.success("Password updated successfully");
      setShowPasswordForm(false);
      setPasswords({ current: '', new: '', confirm: '' });
    } catch (e) {
      toast.error("Failed to update password");
    }
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">Settings</h2>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Profile Card */}
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-slate-800 rounded-xl border border-slate-700 p-6 flex flex-col items-center text-center">
            <div className="w-24 h-24 bg-gradient-to-br from-slate-700 to-slate-600 rounded-full flex items-center justify-center text-slate-300 mb-4 ring-4 ring-slate-900 shadow-xl overflow-hidden">
              <UserCircle size={48} />
            </div>
            <h3 className="text-xl font-bold text-white">{user?.name || 'Admin'}</h3>
            <p className="text-slate-400 text-sm mb-2">{user?.email}</p>
            <span className="px-2 py-1 bg-yellow-500/10 text-yellow-500 text-[10px] font-bold uppercase tracking-wider rounded border border-yellow-500/20 mb-6">
              {user?.role?.replace('_', ' ')}
            </span>

            <button
              onClick={() => setShowPasswordForm(!showPasswordForm)}
              className="w-full py-2 px-4 bg-slate-700 hover:bg-slate-600 text-white rounded-lg text-sm font-medium transition-colors"
            >
              Change Password
            </button>
          </div>

          {showPasswordForm && (
            <div className="bg-slate-800 rounded-xl border border-slate-700 p-6 shadow-lg">
              <h4 className="text-white font-bold mb-4">Update Password</h4>
              <form onSubmit={handlePasswordChange} className="space-y-4">
                <div>
                  <label className="block text-xs text-slate-400 mb-1">New Password</label>
                  <input
                    type="password"
                    required
                    value={passwords.new}
                    onChange={e => setPasswords({ ...passwords, new: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-yellow-500"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-400 mb-1">Confirm Password</label>
                  <input
                    type="password"
                    required
                    value={passwords.confirm}
                    onChange={e => setPasswords({ ...passwords, confirm: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-yellow-500"
                  />
                </div>
                <div className="flex gap-2">
                  <button type="submit" className="flex-1 py-2 bg-yellow-500 text-slate-900 font-bold rounded-lg text-sm">Save</button>
                  <button type="button" onClick={() => setShowPasswordForm(false)} className="px-4 py-2 bg-slate-700 text-white rounded-lg text-sm">Cancel</button>
                </div>
              </form>
            </div>
          )}
        </div>

        {/* General Settings */}
        <div className="lg:col-span-2 bg-slate-800 rounded-xl border border-slate-700 p-6 space-y-6">
          <h3 className="text-lg font-semibold text-white border-b border-slate-700 pb-2">App Configuration</h3>

          <div className="space-y-4">
            {user?.role === 'super_admin' ? (
              <div className="flex items-center justify-between p-4 bg-slate-900/50 rounded-lg border border-slate-700/50">
                <div className="flex items-center gap-3">
                  <div className="p-2 bg-yellow-500/10 rounded-lg text-yellow-500">
                    <Smartphone size={20} />
                  </div>
                  <div>
                    <p className="font-medium text-white">App Maintenance Mode</p>
                    <p className="text-xs text-slate-400">Block District Reporters access</p>
                  </div>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    className="sr-only peer"
                    checked={maintenance}
                    onChange={handleToggleMaintenance}
                  />
                  <div className="w-11 h-6 bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-yellow-500"></div>
                </label>
              </div>
            ) : (
              <div className="p-4 bg-slate-900/30 rounded-lg border border-slate-700/50 text-slate-500 text-sm italic">
                Maintenance settings are only available to Super Admins.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}`;

content = content.substring(0, startIdx) + newSettingsView + content.substring(endIdx);

fs.writeFileSync(filePath, content, 'utf8');
console.log("Successfully updated App.tsx");
