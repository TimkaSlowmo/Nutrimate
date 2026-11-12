// Локальная проверка воркера без Cloudflare: node server/test.mjs
import assert from 'node:assert/strict';
import worker, { buildContext, sanitizeMessages, claimsAction, detectLang, langInstruction, HONEST_REPLY, extractActions } from './src/index.js';

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

// Честность о действиях (жалоба владельца: «добавил», хотя ничего не добавилось)
assert.ok(claimsAction("Sure! I've added 2 eggs to your fridge 🥚"));
assert.ok(claimsAction('Готово, добавил 2 яйца в холодильник!'));
assert.ok(claimsAction('Тоңазытқышқа 2 жұмыртқа қостым'));
assert.ok(!claimsAction('Try an omelette with your eggs 🍳'));
assert.ok(!claimsAction('Попробуй омлет из яиц 🍳'));
assert.equal(detectLang('добавь 2 яйца в холодильник'), 'ru');
assert.equal(detectLang('тоңазытқышқа 2 жұмыртқа қос'), 'kk');
assert.equal(detectLang('add 2 eggs'), 'en');
assert.equal(detectLang('hi', 'ru'), 'ru');
// язык приложения: правило в промпте
assert.match(langInstruction('ru'), /Answer in Russian — the app language — unless the user clearly writes in another language/);
assert.match(langInstruction('kk'), /Answer in Kazakh.*Cyrillic.*the app language — unless the user clearly writes in another language/);
assert.equal(detectLang('what can I cook?', 'kk'), 'kk');
const liar = { AI: { async run(model, input) {
  const last = input.messages[input.messages.length - 1].content;
  assert.match(input.messages[0].content, /CANNOT change anything/);
  return { response: /[а-яё]/i.test(last) ? 'Конечно, добавил 2 яйца в холодильник!' : /қ/.test(last) ? 'Жарайды, қостым!' : "Done! I've added 2 eggs to your fridge." };
} } };
for (const [msg, lang, deviceId] of [['add 2 eggs to my fridge', 'en', 'liar-en-1'], ['добавь 2 яйца в холодильник', 'ru', 'liar-ru-1'], ['тоңазытқышқа 2 жұмыртқа қос', 'kk', 'liar-kk-1']]) {
  const r = await worker.fetch(req({ deviceId, messages: [{ role: 'user', content: msg }], context: ctx }), liar);
  const b = await r.json();
  assert.equal(r.status, 200);
  assert.equal(b.guarded, true, msg);
  assert.equal(b.reply, HONEST_REPLY[lang]);
}
const ru = { AI: { async run(model, input) { assert.match(input.messages[0].content, /Answer in Russian/); return { response: 'Сделай омлет 🍳' }; } } };
assert.equal((await worker.fetch(req({ deviceId: 'lang-ru-1', messages: [{ role: 'user', content: 'Что приготовить?' }], context: ctx }), ru)).status, 200);
const kkLang = { AI: { async run(model, input) { assert.match(input.messages[0].content, /Answer in Kazakh/); return { response: 'Омлет жаса 🍳' }; } } };
assert.equal((await worker.fetch(req({ deviceId: 'lang-kk-1', messages: [{ role: 'user', content: 'hi' }], context: { ...ctx, language: 'kk' } }), kkLang)).status, 200);
assert.match(buildContext({ fridge: [{ name: 'Eggs', qty: 10, daysLeft: 12 }] }), /Eggs ×10 \(12 days left\)/);

// Структурированные действия: ИИ только предлагает, приложение выполняет и подтверждает
let e = extractActions('Okay, passing it to the app 🐾\nACTIONS: [{"type":"add_fridge","name":"Eggs","qty":2}]');
assert.equal(e.reply, 'Okay, passing it to the app 🐾');
assert.deepEqual(e.actions, [{ type: 'add_fridge', name: 'Eggs', qty: 2 }]);
e = extractActions('Хорошо!\n```json\n[{"type":"eat","name":"Banana"}]\n```');
assert.deepEqual(e.actions, [{ type: 'eat', name: 'Banana', qty: 1 }]);
assert.equal(e.reply, 'Хорошо!');
e = extractActions('ACTIONS: [{"type":"delete_everything","name":"Eggs"},{"type":"freeze","name":"Chicken Breast","qty":500}]');
assert.deepEqual(e.actions, [{ type: 'freeze', name: 'Chicken Breast', qty: 99 }]);
assert.deepEqual(extractActions('ACTIONS: [not json').actions, []);
// метка кириллицей (так ответила модель на казахском в smoke-тесте) — действие не теряется и не попадает в текст
e = extractActions('Жарайды! 🐾\nАқырында, жұмыртқа тоңазытқышта сақталады.\n\nАCTIONS: [{"type":"add_fridge","name":"Eggs","qty":2}]');
assert.deepEqual(e.actions, [{ type: 'add_fridge', name: 'Eggs', qty: 2 }]);
assert.ok(!/CTIONS/.test(e.reply), e.reply);
// голый JSON-массив действий на отдельной строке
e = extractActions('Ок!\n[{"type":"eat","name":"Banana","qty":1}]');
assert.deepEqual(e.actions, [{ type: 'eat', name: 'Banana', qty: 1 }]);
// обычный текст со списком в скобках — не действие
assert.deepEqual(extractActions('Try: [eggs, milk]').actions, []);
assert.deepEqual(extractActions('Try an omelette 🍳').actions, []);

const actor = (answer) => ({ AI: { async run(model, input) {
  assert.match(input.messages[0].content, /ACTIONS: \[/);
  return { response: answer(input.messages[input.messages.length - 1].content) };
} } });
for (const [msg, deviceId, answer, want] of [
  ['add 2 eggs to my fridge', 'act-en-1', () => 'Okay 🐾\nACTIONS: [{"type":"add_fridge","name":"Eggs","qty":2}]', [{ type: 'add_fridge', name: 'Eggs', qty: 2 }]],
  ['добавь 2 яйца в холодильник', 'act-ru-1', () => 'Добавил 2 яйца!\nACTIONS: [{"type":"add_fridge","name":"Eggs","qty":2}]', [{ type: 'add_fridge', name: 'Eggs', qty: 2 }]],
  ['тоңазытқышқа 2 жұмыртқа қос', 'act-kk-1', () => 'Жарайды 🐾\nACTIONS: [{"type":"add_fridge","name":"Eggs","qty":2}]', [{ type: 'add_fridge', name: 'Eggs', qty: 2 }]],
  ['купи молоко', 'act-ru-2', () => 'ACTIONS: [{"type":"add_shopping","name":"Milk","qty":1}]', [{ type: 'add_shopping', name: 'Milk', qty: 1 }]],
]) {
  const r = await worker.fetch(req({ deviceId, actions: true, messages: [{ role: 'user', content: msg }], context: ctx }), actor(answer));
  const b = await r.json();
  assert.equal(r.status, 200, msg);
  assert.deepEqual(b.actions, want, msg);
  assert.ok(!claimsAction(b.reply), `reply must not claim: ${b.reply}`);
  assert.ok(!/ACTIONS/.test(b.reply), msg);
}
// без actions — ложное «добавил» заменяется честной подсказкой и в режиме actions
const liarAct = { AI: { async run() { return { response: 'Готово, добавил 2 яйца!' }; } } };
const lr = await (await worker.fetch(req({ deviceId: 'act-liar-1', actions: true, messages: [{ role: 'user', content: 'добавь 2 яйца' }], context: ctx }), liarAct)).json();
assert.equal(lr.guarded, true);
assert.deepEqual(lr.actions, []);
assert.equal(lr.reply, HONEST_REPLY.ru);
const mixup = { AI: { async run() { return { response: 'Жарайды!\nACTIONS: [{"type":"add_freezer","name":"Eggs","qty":2}]' }; } } };
assert.equal((await (await worker.fetch(req({ deviceId: 'act-mixup-1', actions: true, messages: [{ role: 'user', content: 'тоңазытқышқа 2 жұмыртқа қос' }], context: ctx }), mixup)).json()).actions[0].type, 'add_fridge');
const promise = { AI: { async run() { return { response: 'Okay, passing it to the app 🐾' }; } } };
assert.equal((await (await worker.fetch(req({ deviceId: 'act-promise-1', actions: true, messages: [{ role: 'user', content: 'add eggs' }], context: ctx }), promise)).json()).guarded, true);
// старые клиенты (без actions: true) не получают правила действий
const old = { AI: { async run(model, input) { assert.doesNotMatch(input.messages[0].content, /ACTIONS: \[/); return { response: 'Hi 🐾' }; } } };
assert.equal((await worker.fetch(req({ deviceId: 'old-client-1', messages: [{ role: 'user', content: 'hi' }], context: ctx }), old)).status, 200);
console.log(`server tests passed ✅ (${calls} AI calls)`);
