// The API. You don't need to change it: your job is to run it with Docker Compose.
const http = require("node:http");

const port = Number(process.env.PORT || 3000);
http
  .createServer((req, res) => {
    if (req.url === "/api/health") {
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify({ status: "ok", service: "api", db_host: process.env.DB_HOST || null }));
    }
    res.writeHead(404, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: "not found" }));
  })
  .listen(port, () => console.log(`api listening on :${port}`));
