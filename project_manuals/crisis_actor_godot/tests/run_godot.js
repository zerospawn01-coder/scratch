const { spawnSync } = require('child_process');
const fs = require('fs');

// Auto-detect Godot executable path
let godotBin = process.env.GODOT_BIN || 'godot';

if (process.platform === 'win32') {
  const localDefault = 'D:\\Downloads\\Godot_v4.7-stable_win64.exe\\Godot_v4.7-stable_win64.exe';
  if (fs.existsSync(localDefault)) {
    godotBin = localDefault;
  }
}

const args = process.argv.slice(2);
console.log(`Running Godot command: "${godotBin}" ${args.join(' ')}`);

const result = spawnSync(godotBin, args, { stdio: 'inherit', shell: true });
if (result.error) {
  console.error("Execution error:", result.error);
  process.exit(1);
}
process.exit(result.status === null ? 1 : result.status);
