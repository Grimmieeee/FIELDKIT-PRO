const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function checkConnectionOrder(root, requireAligned = false) {
  const reviewed = JSON.parse(fs.readFileSync(path.join(root, 'qa/connection-order-review.json'), 'utf8'));
  const found = new Set();
  const exceptions = new Set();

  for (const directory of ['dist', 'scripts']) {
    for (const file of fs.readdirSync(path.join(root, directory), { recursive: true })) {
      if (!file.toLowerCase().endsWith('.ps1')) continue;
      const relative = [directory, file].join('/').replace(/\\/g, '/');
      const bytes = fs.readFileSync(path.join(root, relative));
      const source = bytes.toString('utf8');
      if (!/\bConnect-ExchangeOnline\b/i.test(source) || !/\bConnect-MgGraph\b/i.test(source)) continue;
      found.add(relative);
      const record = reviewed[relative];
      assert.ok(record, relative + ': dual-service call-path review is required');
      assert.equal(createHash('sha256').update(bytes).digest('hex'), record.sha256,
        relative + ': source changed, repeat the connection-order review');
      assert.ok(['exchange-first', 'open'].includes(record.status) && record.evidence, relative + ': review status and evidence required');
      if (record.status === 'open') exceptions.add(path.basename(relative));
    }
  }
  for (const file of Object.keys(reviewed)) {
    assert.ok(found.has(file), file + ': remove or update the obsolete connection review');
  }

  if (exceptions.size) {
    const message = 'Connection order unresolved: ' + [...exceptions].sort().join(', ');
    if (requireAligned) throw new Error(message);
    console.warn(message);
  }
  console.log('Connection-order review checked against ' + found.size + ' source copies.');
}

if (require.main === module) {
  checkConnectionOrder(path.resolve(__dirname, '../..'), process.argv.includes('--require-aligned'));
}
module.exports = checkConnectionOrder;
