const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

for (const language of ['de', 'en']) {
test(`${language}: default filter, status selection, search and plurals`, () => {
    const template = fs.readFileSync(path.join(__dirname, '../Koha/Plugin/HKS3/SysprefDefaults/tool.tt'), 'utf8');
    const script = template.match(/<script[^>]*>([\s\S]*?)<\/script>/)[1];
    const query = { value: '', addEventListener(event, fn) { this.update = fn; } };
    const status = { value: 'differences', addEventListener(event, fn) { this.update = fn; } };
    const strings = JSON.parse(fs.readFileSync(path.join(__dirname, `../Koha/Plugin/HKS3/SysprefDefaults/i18n/${language}.json`), 'utf8'));
    const visible = { dataset: { one: strings.visible_one, other: strings.visible_other } };
    const rows = ['equal', 'changed', 'missing', 'extra', 'equal'].map((value, i) => ({
        dataset: { status: value, overridden: i === 4 ? '1' : '0' },
        textContent: i === 1 ? 'SearchEngine Zebra DBSearch' : `Preference ${i}`,
    }));
    const document = {
        getElementById(id) { return { 'pref-query': query, 'pref-status': status, 'pref-visible': visible }[id]; },
        querySelectorAll() { return rows; },
    };
    vm.runInNewContext(script, { document });
    assert.equal(rows[0].hidden, true);
    assert.equal(rows[4].hidden, false);
    assert.match(visible.textContent, /^4 /);
    assert.equal(visible.textContent, strings.visible_other.replace('{count}', '4'));
    status.value = 'all'; status.update();
    assert.match(visible.textContent, /^5 /);
    query.value = 'SEARCHengine'; query.update();
    assert.match(visible.textContent, /^1 /);
    assert.equal(visible.textContent, strings.visible_one.replace('{count}', '1'));
    assert.equal(rows[1].hidden, false);
    status.value = 'missing'; status.update();
    assert.match(visible.textContent, /^0 /);
    assert.equal(visible.textContent, strings.visible_other.replace('{count}', '0'));
    query.value = ''; query.update();
    assert.equal(rows[2].hidden, false);
    status.value = 'overridden'; status.update();
    assert.equal(rows[4].hidden, false);
    assert.match(visible.textContent, /^1 /);
});
}
