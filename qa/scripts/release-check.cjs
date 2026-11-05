const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const root=path.resolve(__dirname,'../..'),{q,c}=require('./release-loader.cjs');
const sums = new Map();
for (const line of fs.readFileSync(path.join(root, 'dist/SHA256SUMS.txt'), 'utf8').trim().split(/\r?\n/)) {
  const match = /^([a-f0-9]{64})  (.+)$/.exec(line);
  assert(match, 'Invalid checksum line: ' + line);
  const [, sha256, relative] = match;
  assert(!sums.has(relative), 'Duplicate checksum path: ' + relative);
  sums.set(relative, sha256);
}
const results=[];
function pass(name){results.push({name,result:'PASS'});}
c.fetch=async url=>{
  const relative=new URL(url).pathname.slice(1);
  const filename=path.join(root,'dist',relative);
  const bytes=fs.readFileSync(filename);
  let sent=false;
  return {ok:true,redirected:false,headers:{get:k=>k==='content-type'?'text/plain':k==='content-length'?String(bytes.length):null},body:{getReader:()=>({read:async()=>sent?{done:true}:(sent=true,{done:false,value:bytes}),cancel:async()=>{}})}};
};
(async()=>{
  assert(q.runFrameworkAudit().ok);
  pass('Catalog entries pass framework audit');
  assert.deepEqual(Object.fromEntries(sums), { ...c.FIELD_KIT_RELEASE_SOURCES });
  for (const [relative, sha256] of sums) {
    const bytes = fs.readFileSync(path.join(root, 'dist', relative));
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), sha256, relative);
    const item = q.ITEMS.find(x => x.publishedPath === relative) || { publishedPath: relative };
    const source = await q.resolveSource(item);
    assert.deepEqual(Buffer.from(await new Blob([source]).arrayBuffer()), bytes, relative);
    if (item.operatorCard) assert.equal(item.operatorCard.sourceSha256, sha256, relative);
  }
  pass('Approved release files resolve and save byte-identically; metadata matches source hashes');
  const historicalWithheld = JSON.parse(fs.readFileSync(path.join(root, 'qa/release-manifest.json')));
  const unapprovedItems = q.ITEMS.filter(x => x.publishedPath && !sums.has(x.publishedPath));
  const unapprovedPaths = new Set([
    ...unapprovedItems.map(x => x.publishedPath),
    ...historicalWithheld.source_files.filter(row => row.status === 'withheld' && !sums.has(row.path)).map(row => row.path),
  ]);
  for (const relative of unapprovedPaths) {
    assert(!fs.existsSync(path.join(root, 'dist', relative)), relative);
    assert.throws(() => q.approvedSourceUrl(relative), /withheld/);
  }
  pass('Unapproved source paths are absent and rejected by the resolver');
  for (const item of unapprovedItems) {
    assert(!/id="(?:downloadSource|showSource)"/.test(q.sourceButton(item)), item.file);
  }
  pass('Unapproved cards omit source actions');
  const artifactRoot=path.join(root,'qa/release-test-artifacts');fs.mkdirSync(artifactRoot,{recursive:true});
  for(const [name,build] of [['field-kit-first-run.zip',q.buildSetupBundle],['field-kit-bec.zip',q.buildIRBundle]]){
    const blob=await build();fs.writeFileSync(path.join(artifactRoot,name),Buffer.from(await blob.arrayBuffer()));
  }
  pass('Setup and complete BEC packages build from the established files');
  // A failed source must prevent package creation, including after the happy-path cache test.
  const bec=q.ITEMS.find(x=>x.file==='BEC-RISK-ASSESSMENT.ps1');
  q.sourceCache.clear();const originalFetch=c.fetch;
  c.fetch=async url=>{if(url.endsWith(bec.publishedPath))return {ok:false};return originalFetch(url);};
  await assert.rejects(q.buildIRBundle(),/could not be loaded/);
  pass('One failed BEC source prevents the entire package');
  fs.writeFileSync(path.join(root,'qa/release-check-results.json'),JSON.stringify({scope:'Actual catalog resolver and ZIP builders with filesystem-backed synthetic fetch; no Windows or tenant execution',results},null,2)+'\n');
  console.log(JSON.stringify({passed:results.length,files:sums.size,catalog:q.ITEMS.length,artifactRoot}));
})().catch(e=>{console.error(e);process.exitCode=1});

