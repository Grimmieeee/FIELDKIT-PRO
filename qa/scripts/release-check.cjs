const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { q, c } = require('./release-loader.cjs');

const dist = path.resolve(__dirname, '../../dist');
const sources = c.FIELD_KIT_RELEASE_SOURCES;
const workflow = q.ITEMS.filter(item => /^(BEC-RISK-ASSESSMENT|BEC-CONTAIN-ERADICATE|BEC-RECOVER-VALIDATE)\.ps1$/.test(item.file));

c.fetch = async url => {
  const relative = new URL(url).pathname.slice(1);
  const bytes = fs.readFileSync(path.join(dist, relative));
  let sent = false;
  return {
    ok: true,
    redirected: false,
    headers: { get: key => key === 'content-type' ? 'text/plain' : null },
    body: { getReader: () => ({
      read: async () => sent ? { done: true } : (sent = true, { done: false, value: bytes }),
      cancel: async () => {},
    }) },
  };
};

async function verify() {
  assert.ok(q.runFrameworkAudit().ok);

  const root = path.resolve(dist, '..');
  require('./check-connection-order.cjs')(root, process.argv.includes('--require-aligned'));
  const manifest = Object.entries(sources).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)
    .map(([file, hash]) => hash + '  ' + file).join('\n') + '\n';
  assert.equal(fs.readFileSync(path.join(root, 'qa/V162-SHA256SUMS.txt'), 'utf8'), manifest);
  const verified = JSON.parse(fs.readFileSync(path.join(root, 'qa/operator-verified-2026-11-11.json'), 'utf8'));
  for (const [file, record] of Object.entries(verified.scripts)) {
    const item = q.ITEMS.find(candidate => candidate.file === file);
    assert.ok(item && q.isVerifiedRelease(item), file);
    assert.equal(sources[record.sitePath], record.sha256, file);
    assert.deepEqual(fs.readFileSync(path.join(root, record.path)), fs.readFileSync(path.join(dist, record.sitePath)), file);
  }
  for (const item of q.ITEMS) assert.ok(q.catalogDomain(item), item.displayName);

  for (const [file, hash] of Object.entries(sources)) {
    assert.equal(c.FIELD_KIT_SOURCE_INTEGRITY[file], hash, file);
    const source = await q.resolveSource({ publishedPath: file });
    assert.deepEqual(Buffer.from(source), fs.readFileSync(path.join(dist, file)), file);
  }
  for (const file of fs.readdirSync(path.join(dist, 'published-source'), { recursive: true })) {
    if (file.endsWith('.ps1')) assert.ok(sources['published-source/' + file], file);
  }

  assert.equal(workflow.length, 3);
  const eligible = workflow.every(item => q.isVerifiedRelease(item) || q.isReviewedWorkflowPackage(item)) &&
    (new Set(workflow.map(item => item.version)).size === 1 || workflow.every(item => q.isVerifiedRelease(item)));
  for (const item of workflow) {
    assert.equal(q.startMarkup(item).includes('id="downloadIRWorkflow"'), eligible, item.file);
  }
  if (eligible) {
    assert.ok((await q.buildIRBundle()).size > 0);
  } else {
    await assert.rejects(q.buildIRBundle(), /release review|versions do not match/);
  }

  const first = query => q.ITEMS.map(item => [q.searchScore(item, query), item.displayName])
    .sort((a, b) => b[0] - a[0])[0][1];
  assert.equal(first('delete mailbox rules'), 'Remove Specific Inbox Rule');
  assert.equal(first('remove all inbox rules'), 'Remove All Inbox Rules');
  assert.equal(first('show suspicious inbox rules'), 'Get Mailbox Rules');
  assert.equal(first('check last mailbox logon'), 'Get Mailbox Usage Statistics');
  assert.equal(first('phishing'), 'Create Phishing Search By Subject');
  assert.equal(first('Flush DNS'), 'Flush Resolver Cache');
  assert.equal(first('Spooler Status'), 'Show Service Status');
  console.log(`${q.ITEMS.length} cards, ${Object.keys(sources).length} source files, search and bundle checks passed.`);
}

verify().catch(error => { console.error(error); process.exitCode = 1; });
