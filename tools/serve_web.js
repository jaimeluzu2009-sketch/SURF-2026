// Servidor estático mínimo para probar la exportación web (build/web).
// Uso: node tools/serve_web.js [puerto]
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "build", "web");
const port = Number(process.argv[2] || 8060);
const types = {
	".html": "text/html; charset=utf-8", ".js": "text/javascript", ".wasm": "application/wasm",
	".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
};

http.createServer((req, res) => {
	console.log(`${new Date().toLocaleTimeString()} ${req.socket.remoteAddress} ${req.method} ${req.url}`);
	let rel = decodeURIComponent(req.url.split("?")[0]);
	if (rel === "/") rel = "/index.html";
	const file = path.resolve(root, "." + rel);
	if (!file.startsWith(root)) { res.writeHead(403); return res.end(); }
	fs.readFile(file, (err, data) => {
		if (err) { res.writeHead(404); return res.end("no encontrado"); }
		res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
		res.end(data);
	});
}).listen(port, () => console.log(`BARRELS web en http://localhost:${port}`));
