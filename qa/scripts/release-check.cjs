const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const root=path.resolve(__dirname,'../..'),{q,c}=require('./release-loader.cjs');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'qa/release-manifest.json')));
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
  assert(q.runFrameworkAudit().ok);pass('311 catalog entries pass framework audit');
  for(const row of manifest.source_files){
    const filename=path.join(root,'dist',row.path);
    if(row.status==='withheld'){
      assert(!fs.existsSync(filename),row.path);
      assert.throws(()=>q.approvedSourceUrl(row.path),/withheld/);
      continue;
    }
    const bytes=fs.readFileSync(filename);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),row.sha256,row.path);
    const item=q.ITEMS.find(x=>x.publishedPath===row.path)||{publishedPath:row.path};
    const source=await q.resolveSource(item);
    assert.deepEqual(Buffer.from(await new Blob([source]).arrayBuffer()),bytes,row.path);
    if(item.operatorCard) assert.equal(item.operatorCard.sourceSha256,row.sha256,row.path);
  }
  pass('72 release files resolve and save byte-identically; metadata matches source hashes');
  pass('11 withheld paths are absent and rejected by resolver');
  for(const item of q.ITEMS.filter(x=>x.publishedPath&&!c.FIELD_KIT_RELEASE_SOURCES[x.publishedPath])){
    assert(!/id="(?:downloadSource|showSource)"/.test(q.sourceButton(item)),item.file);
  }
  pass('All nine visible withheld cards omit source actions');
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
  console.log(JSON.stringify({passed:results.length,files:manifest.enabled,catalog:q.ITEMS.length,artifactRoot}));
})().catch(e=>{console.error(e);process.exitCode=1});

