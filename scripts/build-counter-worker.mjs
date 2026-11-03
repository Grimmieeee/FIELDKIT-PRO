import {readdirSync,readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
const types={'.html':'text/html; charset=utf-8','.json':'application/json; charset=utf-8','.ps1':'application/octet-stream','.md':'text/markdown; charset=utf-8','.zip':'application/zip','.txt':'text/plain; charset=utf-8','.svg':'image/svg+xml','.png':'image/png'};
const files={};
function walk(dir){for(const e of readdirSync(dir,{withFileTypes:true})){if(e.name==='server'||e.name==='.openai')continue;const p=path.join(dir,e.name);if(e.isDirectory())walk(p);else files['/'+path.relative('dist',p).split(path.sep).join('/')]=[types[path.extname(p)]||'application/octet-stream',readFileSync(p).toString('base64')];}}
walk('dist');mkdirSync('dist/server',{recursive:true});mkdirSync('dist/.openai',{recursive:true});
writeFileSync('dist/server/index.js','const FILES='+JSON.stringify(files)+';\n'+readFileSync('worker/router.mjs','utf8'));
writeFileSync('dist/.openai/hosting.json',readFileSync('.openai/hosting.json'));
console.log('Embedded '+Object.keys(files).length+' unchanged asset payloads');
