const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');const {q,c}=require('./release-loader.cjs');const results=[];
async function check(name,fn){await fn();results.push({name,result:'PASS'})}
const path='published-source/tenant/QA.ps1',item={publishedPath:path};let body,status=200,redirected=false,mime='text/plain',headerSize;
c.fetch=async(url,opts)=>{assert.equal(opts.credentials,'same-origin');assert.equal(opts.redirect,'error');assert.equal(opts.cache,'no-store');let read=false;return {ok:status===200,redirected,headers:{get(k){return k==='content-type'?mime:k==='content-length'?headerSize:null}},body:{getReader(){return {async read(){if(read)return {done:true};read=true;return {done:false,value:body}},async cancel(){}}}}}};
function setup(bytes){body=Buffer.from(bytes);q.sourceCache.clear();c.FIELD_KIT_SOURCE_INTEGRITY={...c.FIELD_KIT_SOURCE_INTEGRITY,[path]:crypto.createHash('sha256').update(body).digest('hex')};c.FIELD_KIT_RELEASE_SOURCES={...c.FIELD_KIT_RELEASE_SOURCES,[path]:c.FIELD_KIT_SOURCE_INTEGRITY[path]};status=200;redirected=false;mime='text/plain';headerSize=null}
(async()=>{
await check('Approved bytes preserve BOM and CRLF when saved as Blob',async()=>{const bytes=Buffer.concat([Buffer.from([239,187,191]),Buffer.from('Write-Host "sample"\r\n')]);setup(bytes);const text=await q.resolveSource(item);assert.deepEqual(Buffer.from(await new Blob([text]).arrayBuffer()),bytes)});
await check('Checksum mismatch blocks',async()=>{setup('good');body=Buffer.from('bad');await assert.rejects(q.resolveSource(item),/checksum mismatch/)});
await check('Empty file blocks',async()=>{setup('');await assert.rejects(q.resolveSource(item),/empty/)});
await check('HTML MIME blocks',async()=>{setup('good');mime='text/html';await assert.rejects(q.resolveSource(item),/page instead/)});
await check('HTML body disguised as source blocks',async()=>{setup('<!doctype html><html>failure</html>');await assert.rejects(q.resolveSource(item),/page instead/)});
await check('Redirect response blocks',async()=>{setup('good');redirected=true;await assert.rejects(q.resolveSource(item),/could not be loaded/)});
await check('HTTP failure blocks',async()=>{setup('good');status=404;await assert.rejects(q.resolveSource(item),/could not be loaded/)});
await check('Oversized declared length blocks',async()=>{setup('good');headerSize=2097153;await assert.rejects(q.resolveSource(item),/limit/)});
await check('Oversized stream blocks',async()=>{setup(Buffer.alloc(2097153,65));await assert.rejects(q.resolveSource(item),/limit/)});
await check('Invalid UTF8 blocks',async()=>{setup(Buffer.from([255,254,255]));await assert.rejects(q.resolveSource(item))});
await check('Traversal path blocks',()=>assert.throws(()=>q.approvedSourceUrl('published-source/../QA.ps1'),/not approved/));
await check('External source URL blocks',()=>assert.throws(()=>q.approvedSourceUrl('https://example.test/QA.ps1'),/not approved/));
await check('Missing checksum blocks',()=>assert.throws(()=>q.approvedSourceUrl('published-source/missing.ps1'),/withheld|checksum/));
fs.writeFileSync(require('path').join(__dirname,'../download-integrity-tests.json'),JSON.stringify({scope:'Extracted actual resolveSource and approvedSourceUrl; synthetic fetch responses only, not browser download acceptance',results},null,2)+'\n');console.log('DOWNLOAD QA: '+results.length+' passed');
})().catch(e=>{console.error(e);process.exitCode=1});

