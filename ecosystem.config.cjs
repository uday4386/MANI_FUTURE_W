module.exports = {
  apps: [
    {
      name: "samanyudu-api",
      cwd: "./backend_api",
      script: "index.js"
    },
    {
      name: "samanyudu-web",
      cwd: ".",
      script: "npm.cmd",
      args: "run dev -- --host 0.0.0.0 --port 5173"
    },
    {
      name: "samanyudu-public",
      cwd: "./public_web_app",
      script: "npx.cmd",
      args: "serve -l 8080"
    }
  ]
};
