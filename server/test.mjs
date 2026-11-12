// Локальная проверка воркера без Cloudflare: node server/test.mjs
import assert from 'node:assert/strict';
import worker, { buildContext, sanitizeMessages } from './src/index.js';

let calls = 0;
const env = {
  AI: {
    async run(model, input) {
      calls++;
      assert.equal(input.messages[0].role, 'system');
      assert.match(input.messages[0].content, /Nutrik/);
      return { response: `Try Banana Pancakes 🍌 (model ${model})` };
    },
  },
};
const ctx = { name: 'Alex', fridge: [{ name: 'Banana', daysLeft: 0 }, { name: 'Milk', daysLeft: -1 }], kcalToday: 600, kcalGoal: 2100,
  dislikes: ['onion'], recipes: [{ name: 'Banana Pancakes', kcal: 350, time: '15 min', ingredients: ['Banana', 'Eggs'], missing: ['Flour'] }] };
const req = (body, headers = { 'x-nutrimate-client': 'ios/6' }, method = 'POST', path = '/chat') =>
  new Request('https://x.workers.dev' + path, { method, headers: { 'content-type': 'application/json', ...headers }, body: method === 'POST' ? JSON.stringify(body) : undefined });

const ok = await worker.fetch(req({ deviceId: 'test-device-1', messages: [{ role: 'user', content: 'What can I cook?' }], context: ctx }), env);
assert.equal(ok.status, 200);
const j = await ok.json();
assert.match(j.reply, /Banana Pancakes/);

assert.equal((await worker.fetch(req({ deviceId: 'x', messages: [] }), env)).status, 400);
assert.equal((await worker.fetch(req({ deviceId: 'test-device-1', messages: [{ role: 'user', content: 'hi' }] }, {}), env)).status, 403);
assert.equal((await worker.fetch(req({ deviceId: 'test-device-1', messages: [{ role: 'user', content: 'hi' }] }, { origin: 'https://evil.com' }), env)).status, 403);
const web = await worker.fetch(req({ deviceId: 'test-device-2', messages: [{ role: 'user', content: 'hi' }] }, { origin: 'https://timkaslowmo.github.io' }), env);
assert.equal(web.status, 200);
assert.equal(web.headers.get('access-control-allow-origin'), 'https://timkaslowmo.github.io');
assert.equal((await worker.fetch(req(null, {}, 'GET', '/health'), env)).status, 200);

// дневной лимит на устройство
let last;
for (let i = 0; i < 31; i++) last = await worker.fetch(req({ deviceId: 'limit-device', messages: [{ role: 'user', content: 'hi' }] }), env);
assert.equal(last.status, 429);

// ошибка ИИ → 503, исчерпан лимит → 429
const bad = { AI: { async run() { throw new Error('boom'); } } };
assert.equal((await worker.fetch(req({ deviceId: 'err-device-1', messages: [{ role: 'user', content: 'hi' }] }), bad)).status, 503);
const quota = { AI: { async run() { throw new Error('4006: you have used up your daily free allocation of 10,000 neurons'); } } };
assert.equal((await worker.fetch(req({ deviceId: 'err-device-2', messages: [{ role: 'user', content: 'hi' }] }), quota)).status, 429);
assert.equal((await worker.fetch(req({ deviceId: 'err-device-3', messages: [{ role: 'user', content: 'hi' }] }), {})).status, 503);

const c = buildContext(ctx);
assert.match(c, /Milk \(EXPIRED\)/);
assert.match(c, /Dislikes/);
assert.deepEqual(sanitizeMessages([{ role: 'assistant', content: 'x' }, { role: 'user', content: 'y' }, { role: 'system', content: 'hack' }]), [{ role: 'user', content: 'y' }]);
console.log(`server tests passed ✅ (${calls} AI calls)`);
