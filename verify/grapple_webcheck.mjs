// Browser boundary for the Grapple vortex: this deliberately uses the normal
// web playtest route and a real browser click. Godot's headless mouse test
// covers rays and hit resolution; this check proves the web player reaches a
// visible live wave without depending on fragile browser pointer lock.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/grapple-web.png';
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json' };
const server = http.createServer((req, res) => {
	let file = decodeURIComponent(req.url.split('?')[0]);
	if (file === '/') file = '/index.html';
	const resolved = path.join(dir, file);
	if (!fs.existsSync(resolved)) { res.writeHead(404); res.end('missing'); return; }
	res.writeHead(200, {
		'Content-Type': TYPES[path.extname(resolved)] || 'application/octet-stream',
		'Cross-Origin-Opener-Policy': 'same-origin',
		'Cross-Origin-Embedder-Policy': 'require-corp',
	});
	fs.createReadStream(resolved).pipe(res);
});
await new Promise(resolve => server.listen(8768, resolve));

const browser = await chromium.launch({ args: [
	'--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
	'--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
await page.addInitScript(() => {
	window.__pointerLockRequests = [];
	const original = HTMLCanvasElement.prototype.requestPointerLock;
	HTMLCanvasElement.prototype.requestPointerLock = function(...args) {
		window.__pointerLockRequests.push({
			id: this.id,
			connected: this.isConnected,
			ownerIsDocument: this.ownerDocument === document,
			at: performance.now(),
		});
		return original.apply(this, args);
	};
});
const errors = [];
const trace = [];
const startedAt = Date.now();
page.on('console', message => {
	if (message.type() === 'error') errors.push({ at: Date.now() - startedAt, message: message.text() });
});
page.on('pageerror', error => errors.push({ at: Date.now() - startedAt, message: String(error) }));

async function click(x, y, pause = 250) {
	await page.mouse.click(x, y);
	if (pause > 0) await page.waitForTimeout(pause);
}

async function checkpoint(name) {
	const state = await page.evaluate(() => {
		const canvas = document.querySelector('canvas');
		return {
			canvas: !!canvas,
			canvasConnected: !!canvas && canvas.isConnected,
			viewport: [innerWidth, innerHeight],
		};
	});
	trace.push({ name, at: Date.now() - startedAt, state });
	await page.screenshot({ path: `/tmp/pr90-grapple-${name}.png` });
}

// Return distinct, visibly lit yellow/green blobs. The crosshair is filtered
// out by its tiny center-box; a real first wave must leave four other targets.
async function coloredSphereBlobs() {
	return page.evaluate(() => {
		const canvas = document.querySelector('canvas');
		if (!canvas) return [];
		const copy = document.createElement('canvas');
		copy.width = canvas.width; copy.height = canvas.height;
		const context = copy.getContext('2d');
		context.drawImage(canvas, 0, 0);
		const { data, width, height } = context.getImageData(0, 0, copy.width, copy.height);
		const seen = new Uint8Array(width * height);
		const blobs = [];
		const isSpherePixel = (index) => {
			const r = data[index], g = data[index + 1], b = data[index + 2];
			return (r > 150 && g > 115 && b < 130) || (g > 145 && r < 160 && b < 150);
		};
		for (let y = 0; y < height; y += 2) for (let x = 0; x < width; x += 2) {
			const seed = y * width + x;
			if (seen[seed] || !isSpherePixel(seed * 4)) continue;
			const queue = [[x, y]];
			seen[seed] = 1;
			let count = 0, sumX = 0, sumY = 0, sumR = 0, sumG = 0;
			while (queue.length) {
				const [px, py] = queue.pop();
				const pixel = py * width + px;
				const offset = pixel * 4;
				if (!isSpherePixel(offset)) continue;
				count++; sumX += px; sumY += py; sumR += data[offset]; sumG += data[offset + 1];
				for (const [nx, ny] of [[px + 2, py], [px - 2, py], [px, py + 2], [px, py - 2]]) {
					if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
					const next = ny * width + nx;
					if (!seen[next] && isSpherePixel(next * 4)) { seen[next] = 1; queue.push([nx, ny]); }
				}
			}
			const centerX = sumX / Math.max(1, count), centerY = sumY / Math.max(1, count);
			if (count >= 4 && (Math.abs(centerX - width / 2) > 30 || Math.abs(centerY - height / 2) > 30)) {
				blobs.push({ x: centerX, y: centerY, color: sumR > sumG ? 'yellow' : 'green', pixels: count });
			}
		}
		return blobs;
	});
}

await page.goto('http://localhost:8768/?special=1', { waitUntil: 'load' });
await page.waitForTimeout(25000); // WebAssembly compile plus Godot boot.
await checkpoint('title');

// First special starts as the tutorial. Enter it and skip it, then use the
// exact regular confirm -> chooser -> Musashi route a subsequent player gets.
await click(640, 405, 350); // first Play Special Encounter Test
await checkpoint('first-battle');
await click(1100, 548, 1400); // Skip Tutorial
await checkpoint('title-after-skip');
await click(640, 405, 350); // subsequent Play Special Encounter Test
await checkpoint('warning');
await click(640, 427, 700); // Enter
await checkpoint('chooser');
await click(1025, 335, 150); // choose Musashi
await checkpoint('musashi-selected');
await click(722, 542, 650); // Send Them In
await checkpoint('battle');
await click(165, 548, 150); // Attack
await checkpoint('moves');
await click(165, 664, 150); // Precise Tap
await checkpoint('targets');
await click(165, 664, 4200); // Angler target, then its special attack and vortex setup
await checkpoint('vortex-before-start');

await click(640, 365, 1800); // visible-cursor start button, then title hold
const pointerRequests = await page.evaluate(() => window.__pointerLockRequests || []);
const blobs = await coloredSphereBlobs();
await page.screenshot({ path: out });

console.log('grapple web ' + JSON.stringify({ pointerRequests, blobs, errors, trace }));
await browser.close();
await new Promise(resolve => server.close(resolve));

if (errors.length || pointerRequests.length || blobs.length < 4) process.exit(1);
console.log('GRAPPLE WEB: normal browser route exposed a live colored vortex wave without pointer-lock errors');
