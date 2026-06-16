// Downloads real elevation (Terrarium) + satellite imagery (Esri World Imagery)
// tiles for the San Francisco Bay, into /tmp/dogfight/geo/{elev,imgry}, and
// writes meta.json describing the tile mosaic. No external deps.
import { mkdirSync, writeFileSync } from 'node:fs';

const Z = 13;
// SF Bay bounding box: Golden Gate, SF, Bay Bridge, Marin, East Bay, Alcatraz.
const BBOX = { minLon: -122.555, maxLon: -122.300, minLat: 37.735, maxLat: 37.895 };
const OUT = '/tmp/dogfight/geo';
mkdirSync(`${OUT}/elev`, { recursive: true });
mkdirSync(`${OUT}/imgry`, { recursive: true });

const lon2tilex = (lon, z) => (lon + 180) / 360 * 2 ** z;
const lat2tiley = (lat, z) => {
  const r = lat * Math.PI / 180;
  return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * 2 ** z;
};

const x0 = Math.floor(lon2tilex(BBOX.minLon, Z));
const x1 = Math.floor(lon2tilex(BBOX.maxLon, Z));
const y0 = Math.floor(lat2tiley(BBOX.maxLat, Z)); // north = smaller y
const y1 = Math.floor(lat2tiley(BBOX.minLat, Z));
const nx = x1 - x0 + 1, ny = y1 - y0 + 1;
console.log(`z=${Z} tiles x:${x0}..${x1} (${nx})  y:${y0}..${y1} (${ny})  total ${nx * ny} each source`);

async function get(url, path) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url);
      if (res.ok) { writeFileSync(path, Buffer.from(await res.arrayBuffer())); return true; }
    } catch {}
    await new Promise(r => setTimeout(r, 300));
  }
  console.error(`FAIL ${url}`); return false;
}

const jobs = [];
for (let x = x0; x <= x1; x++) {
  for (let y = y0; y <= y1; y++) {
    jobs.push(() => get(`https://s3.amazonaws.com/elevation-tiles-prod/terrarium/${Z}/${x}/${y}.png`, `${OUT}/elev/${x}_${y}.png`));
    jobs.push(() => get(`https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/${Z}/${y}/${x}`, `${OUT}/imgry/${x}_${y}.jpg`));
  }
}
// Limited concurrency.
let i = 0, ok = 0;
async function worker() { while (i < jobs.length) { const j = jobs[i++]; if (await j()) ok++; } }
await Promise.all(Array.from({ length: 8 }, worker));
console.log(`downloaded ${ok}/${jobs.length} tiles`);

writeFileSync(`${OUT}/meta.json`, JSON.stringify({
  z: Z, x0, y0, nx, ny, tileSize: 256,
  mosaicW: nx * 256, mosaicH: ny * 256, bbox: BBOX,
}, null, 2));
console.log('wrote meta.json');
