// NutriMate · Nutrik AI — Cloudflare Worker (бесплатный тариф Workers Free + Workers AI).
// POST /vision { deviceId, image(base64 JPEG), mode: food|receipt } → { items:[{name, qty, confidence}] } — см. ниже.
// POST /chat  { deviceId, messages: [{role, content}], context: {...}, actions?: true }  →  200 { reply, model, actions? }
// actions: true — клиент умеет сам выполнять действия: ИИ может ПРЕДЛОЖИТЬ их в структурированном виде
// [{type: add_fridge|add_freezer|add_shopping|eat|discard|freeze, name, qty}], приложение проверяет имя по базе,
// выполняет и само пишет подтверждение по факту. Текст ИИ никогда не утверждает, что действие сделано.
// Любой не-200 ответ (429 лимит, 503 ИИ недоступен, 400 плохой запрос) клиент молча
// заменяет офлайн-ответом NutrikBrain. Ключей в коде нет: ИИ доступен через привязку env.AI.

const MODELS = [
  '@cf/meta/llama-3.1-8b-instruct-fp8-fast', // быстрая и дешёвая (мало «нейронов» из бесплатного лимита)
  '@cf/meta/llama-3.2-3b-instruct',          // запасная, если первая недоступна
];
const DAILY_LIMIT_DEVICE = 30;   // сообщений в день на устройство
const DAILY_LIMIT_IP = 120;      // и на IP (защита от подмены deviceId)
const MAX_MESSAGES = 10;
const MAX_MSG_CHARS = 600;
const MAX_CONTEXT_CHARS = 2500;
const MAX_TOKENS = 320;
const ALLOWED_ORIGINS = ['https://timkaslowmo.github.io'];

export const SYSTEM_PROMPT = `You are Nutrik, the small, clumsy and very cute helper of the NutriMate app. You have tiny short legs, you sometimes trip over carrots, and you love food.
Your mission: help the user eat well and NOT throw food away (NutriMate is a student project against food waste in Almaty).
Rules:
- Answer SHORT: 1-4 sentences or a short list. Friendly and warm, 1-2 emoji per answer.
- Answer in the language named at the end of these rules (the app language).
- When suggesting what to cook, prefer the user's fridge, especially products that expire soon. Prefer recipes from the "Recipes from the app" list and name them exactly as written there. Only say a recipe is "in the app" if it is in that list; otherwise just describe a simple idea. Give grams and short steps only if asked.
- Respect disliked foods: never suggest them.
- Never give medical diagnoses, never encourage strict diets, fasting or eating far below the calorie goal. For health problems, suggest seeing a doctor.
- If the question is not about food, cooking, groceries, storage, nutrition or the app, gently bring the talk back to food in one sentence.
- Never invent the user's data: use only the context below. Do not mention that you got "context".
- You CANNOT change anything in the app yourself: you cannot add, remove, log, freeze or move food, and you cannot edit the shopping list. Never say "I added", "I logged", "done", "добавил", "записал" or similar.`;

const NO_ACTIONS_RULE = `
- The app does these actions itself when the user writes a command like "add 2 eggs to fridge", "I ate a banana", "threw away kefir", "freeze the chicken", "add milk to shopping list". If the user asks for such an action, say you can't do it from the chat and show the exact command to type.`;

export const ACTIONS_RULE = `
- ACTIONS PROTOCOL. The app can do actions for the user. If the user's LAST message asks to add food to the fridge or freezer, says they ate, bought, threw away or froze food, or asks to add something to the shopping list, you MUST end your answer with one line that starts with ACTIONS: followed by a JSON array. Do not tell the user to type a command — the app does it from your ACTIONS line.
  Types: add_fridge, add_freezer, add_shopping, eat, discard, freeze. "name" = simple English food name ("Eggs", "Milk", "Chicken Breast", "Banana"), even if the user wrote in Russian or Kazakh. "qty" = whole number, default 1.
  Your text must NOT say it is done (no "added", "добавил", "қостым") — the app will confirm what really happened. Write one short friendly line instead (a storage tip or "Okay! 🐾").
  Never output ACTIONS for questions, recipes or advice.
  Examples:
  User: add 2 eggs to my fridge → Okay! Eggs keep about 3 weeks in the fridge 🥚
ACTIONS: [{"type":"add_fridge","name":"Eggs","qty":2}]
  User: добавь молоко в список покупок → Хорошо! 🐾
ACTIONS: [{"type":"add_shopping","name":"Milk","qty":1}]
  User: тоңазытқышқа 3 алма қос → Жарайды! 🍎
ACTIONS: [{"type":"add_fridge","name":"Apple","qty":3}]
  User: я съел банан → Приятного аппетита! 🍌
ACTIONS: [{"type":"eat","name":"Banana","qty":1}]`;

// В режиме actions обещание «передаю приложению» без ACTIONS — тоже неправда
const PROMISES_ACTION = /(passing it to the app|i'?ll add|i will add|сейчас добавлю|передаю приложению|okay! 🐾$)/i;

const ACTION_TYPES = new Set(['add_fridge', 'add_freezer', 'add_shopping', 'eat', 'discard', 'freeze']);

const HOMOGLYPHS = { А: 'A', В: 'B', С: 'C', Е: 'E', Н: 'H', І: 'I', К: 'K', М: 'M', О: 'O', Р: 'P', Т: 'T', Х: 'X', Ѕ: 'S' };
const toLatin = (s) => String(s).toUpperCase().replace(/[АВСЕНІКМОРТХЅ]/g, (ch) => HOMOGLYPHS[ch] || ch);

// Достаём «ACTIONS: [...]» (или ```json [...]```) из ответа модели, проверяем и убираем из текста.
export function extractActions(text) {
  let reply = String(text || '');
  let raw = null;
  const block = reply.match(/```(?:json)?\s*(\[[\s\S]*?"type"[\s\S]*?\])\s*```/i);
  if (block) { raw = block[1]; reply = reply.replace(block[0], ''); }
  else {
    // Модель иногда пишет метку кириллицей («АCTIONS») или без метки — принимаем и это.
    for (const m of reply.matchAll(/^[ \t>*`]*([^\s:\[`]{5,9})?\s*:?\s*(\[\s*\{[\s\S]*?\])\s*`*\s*$/gim)) {
      if (!m[1] || toLatin(m[1]).startsWith('ACTION')) { raw = m[2]; reply = reply.replace(m[0], ''); break; }
    }
  }
  let actions = [];
  if (raw) {
    try {
      const arr = JSON.parse(raw);
      if (Array.isArray(arr)) {
        actions = arr.slice(0, 5).map((a) => ({
          type: String(a?.type || '').toLowerCase().trim(),
          name: clip(String(a?.name || ''), 40),
          qty: Math.min(99, Math.max(1, Math.round(Number(a?.qty) || 1))),
        })).filter((a) => ACTION_TYPES.has(a.type) && /\p{L}/u.test(a.name));
      }
    } catch (_) { actions = []; }
  }
  reply = reply.replace(/\n{3,}/g, '\n\n').trim();
  return { reply, actions };
}

const LANG_NAMES = { en: 'English', ru: 'Russian', kk: 'Kazakh (Cyrillic)' };

// Честность: ИИ не может менять данные. Если модель всё же «отчиталась» о действии — заменяем ответ.
const ACTION_CLAIMS = [
  /\bi('ve| have)? (just )?(added|put|logged|removed|deleted|froze|frozen|moved|marked|updated|saved)\b/i,
  /\b(added|logged|moved|put) (it|them|\d+|two|three|some|your|the)\b.*\b(fridge|freezer|pantry|list|diary|log)\b/i,
  /\b(has|have) been (added|logged|removed|frozen)\b/i,
  /(добавил|добавила|добавлено|записал|записала|положил|положила|выбросил|удалил|заморозил|отметил)/i,
  /(қостым|қосылды|жаздым|салдым|тастадым|мұздаттым)/i,
];
export const claimsAction = (text) => ACTION_CLAIMS.some((re) => re.test(String(text || '')));

/** Правило языка для системного промпта: язык приложения, если пользователь явно не пишет на другом. */
export function langInstruction(lang) {
  const name = LANG_NAMES[lang] || LANG_NAMES.en;
  return `\n- Answer in ${name}${lang === 'kk' ? ' (Cyrillic script, simple correct Kazakh)' : ''} — the app language — unless the user clearly writes in another language. Never mix languages in one answer.`;
}

export function detectLang(text, hint) {
  if (hint && LANG_NAMES[hint]) return hint;
  const t = String(text || '');
  if (/[әғқңөұүһі]/i.test(t)) return 'kk';
  if (/[а-яё]/i.test(t)) return 'ru';
  return 'en';
}

export const HONEST_REPLY = {
  en: "🙈 I can't change your fridge from the chat myself. Type a command and the app will really do it, e.g. \"add 2 eggs to fridge\", \"I ate a banana\" or \"add milk to shopping list\".",
  ru: '🙈 Сам я из чата ничего не меняю. Напиши команду — и приложение правда это сделает, например: «добавь 2 яйца в холодильник», «съел банан» или «добавь молоко в список покупок».',
  kk: '🙈 Мен чаттан ештеңені өзім өзгерте алмаймын. Команда жаз — қосымша шынымен орындайды, мысалы: «тоңазытқышқа 2 жұмыртқа қос» немесе «банан жедім».',
};

const json = (obj, status = 200, headers = {}) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json; charset=utf-8', ...headers } });

function corsHeaders(origin) {
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    return {
      'access-control-allow-origin': origin,
      'access-control-allow-methods': 'POST, GET, OPTIONS',
      'access-control-allow-headers': 'content-type, x-nutrimate-client',
      'access-control-max-age': '86400',
      vary: 'origin',
    };
  }
  return {};
}

const clip = (s, n) => (typeof s === 'string' ? s.replace(/\s+/g, ' ').trim().slice(0, n) : '');
const today = () => new Date().toISOString().slice(0, 10);

// Счётчики: Workers KV (если владелец добавит привязку LIMITS) или память изолята (бесплатно, «примерно»).
const memory = new Map();
async function bump(env, key, limit) {
  const k = `${today()}:${key}`;
  if (env.LIMITS) {
    try {
      const n = parseInt((await env.LIMITS.get(k)) || '0', 10);
      if (n >= limit) return false;
      await env.LIMITS.put(k, String(n + 1), { expirationTtl: 60 * 60 * 26 });
      return true;
    } catch (_) { /* KV недоступен → память */ }
  }
  if (memory.size > 5000) memory.clear();
  const n = memory.get(k) || 0;
  if (n >= limit) return false;
  memory.set(k, n + 1);
  return true;
}

export function buildContext(ctx = {}) {
  const lines = [];
  const name = clip(ctx.name, 40);
  if (name) lines.push(`User's name: ${name}`);
  if (Array.isArray(ctx.fridge) && ctx.fridge.length) {
    const items = ctx.fridge.slice(0, 40).map((f) => {
      const d = Number(f.daysLeft);
      const when = !Number.isFinite(d) ? '' : d < 0 ? ' (EXPIRED)' : d === 0 ? ' (expires today)' : d === 1 ? ' (expires tomorrow)' : ` (${d} days left)`;
      const q = Number(f.qty) > 1 ? ` ×${Math.min(999, Math.round(Number(f.qty)))}` : '';
      return `${clip(f.name, 40)}${q}${when}`;
    });
    lines.push(`Fridge (soonest first): ${items.join(', ')}`);
  } else {
    lines.push('Fridge: empty');
  }
  if (Number.isFinite(Number(ctx.kcalToday)) && Number.isFinite(Number(ctx.kcalGoal))) {
    lines.push(`Calories today: ${Math.round(ctx.kcalToday)} of ${Math.round(ctx.kcalGoal)} kcal goal`);
  }
  if (Array.isArray(ctx.dislikes) && ctx.dislikes.length) {
    lines.push(`Dislikes (never suggest): ${ctx.dislikes.slice(0, 20).map((d) => clip(d, 30)).join(', ')}`);
  }
  if (Array.isArray(ctx.recipes) && ctx.recipes.length) {
    lines.push('Recipes from the app (best match first):');
    for (const r of ctx.recipes.slice(0, 8)) {
      const ings = Array.isArray(r.ingredients) ? r.ingredients.slice(0, 10).map((i) => clip(i, 40)).join(', ') : '';
      const miss = Array.isArray(r.missing) && r.missing.length ? `; missing: ${r.missing.slice(0, 5).map((m) => clip(m, 30)).join(', ')}` : '';
      lines.push(`- ${clip(r.name, 60)} (${Math.round(Number(r.kcal) || 0)} kcal/serving, ${clip(r.time, 15)}): ${ings}${miss}`);
    }
  }
  return lines.join('\n').slice(0, MAX_CONTEXT_CHARS);
}

export function sanitizeMessages(messages) {
  if (!Array.isArray(messages)) return [];
  const out = messages
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
    .slice(-MAX_MESSAGES)
    .map((m) => ({ role: m.role, content: clip(m.content, MAX_MSG_CHARS) }))
    .filter((m) => m.content);
  while (out.length && out[0].role !== 'user') out.shift();
  return out;
}

async function runModel(env, messages) {
  let lastErr;
  for (const model of MODELS) {
    try {
      const res = await env.AI.run(model, { messages, max_tokens: MAX_TOKENS, temperature: 0.6 });
      const text = typeof res === 'string' ? res
        : res?.response ?? res?.result?.response ?? res?.choices?.[0]?.message?.content ?? '';
      if (typeof text === 'string' && text.trim()) return { reply: text.trim().slice(0, 1500), model };
      lastErr = new Error('empty');
    } catch (e) {
      lastErr = e;
      // исчерпан бесплатный дневной лимит — не пробуем дальше
      if (/neuron|quota|limit|4006|3036/i.test(String(e?.message || e))) throw Object.assign(new Error('quota'), { quota: true });
    }
  }
  throw lastErr || new Error('ai failed');
}


// ───────────── POST /vision — распознавание еды по фото (бесплатная vision-модель Workers AI) ─────────────
// { deviceId, image: "<base64 JPEG ≤ 768 px>", mode?: "food"|"receipt", language? } → 200 { items:[{name, qty, confidence}], model }
// Фото нигде не сохраняется и не логируется: только передаётся модели и сразу забывается.
export const VISION_MODELS = [
  { id: '@cf/meta/llama-4-scout-17b-16e-instruct', style: 'openai' }, // мультимодальная, без лицензионного «agree»
  { id: '@cf/google/gemma-3-12b-it', style: 'openai' },                // запасная
  { id: '@cf/meta/llama-3.2-11b-vision-instruct', style: 'image' },    // запасная №2 (нужно один раз принять лицензию)
];
const VISION_LIMIT_DEVICE = 15;   // фото в день на устройство
const VISION_LIMIT_IP = 45;       // и на IP
const VISION_LIMIT_TOTAL = 400;   // и всего на изолят в день — чтобы фото не съели бесплатные нейроны чата
const MAX_IMAGE_B64 = 420000;     // ≈ 310 КБ JPEG — 768 px с запасом

export const VISION_PROMPT = {
  food: `You are a food recognizer for a fridge app. Look at the photo and list every distinct FOOD or DRINK product you can see (fruit, vegetables, packaged groceries, dishes).
Return ONLY JSON, no other text: {"items":[{"name":"Banana","qty":5,"confidence":0.9}]}
Rules: "name" = a short common English grocery name, singular ("Banana", "Red Apple", "Milk", "Chicken Breast", "Cherry Tomato"). Be specific (say "Lime", not "Citrus"; "Bell Pepper", not "Vegetable"). "qty" = how many pieces/packs you can count (1 if unsure). "confidence" = 0..1. At most 8 items. If there is no food, return {"items":[]}. Never invent items you cannot see. Read brand labels only to identify the product type.`,
  receipt: `This is a photo of a grocery store receipt (any language: English, Russian, Kazakh). List the FOOD products bought.
Return ONLY JSON, no other text: {"items":[{"name":"Milk","qty":2,"confidence":0.9}]}
Rules: "name" = a short common English grocery name, singular, translated from the receipt line ("МОЛОКО 2.5% 1Л" → "Milk", "ЯЙЦА С0 10ШТ" → "Eggs" qty 10). Skip non-food lines (bags, totals, discounts, cards). "qty" = the count on the line (1 if unclear). At most 25 items. If it is not a receipt, return {"items":[]}.`,
};

/** Достаём {items:[...]} из ответа модели и чистим его. */
export function parseVision(out, max = 8) {
  let obj = out;
  if (typeof out !== 'object' || out === null || Array.isArray(out)) {
    const t = String(out ?? '');
    const iObj = t.indexOf('{'), iArr = t.indexOf('[');
    const tryParse = (re) => { const m = t.match(re); try { return m ? JSON.parse(m[0]) : null; } catch (_) { return null; } };
    const asObj = () => tryParse(/\{[\s\S]*\}/), asArr = () => { const a = tryParse(/\[[\s\S]*\]/); return Array.isArray(a) ? { items: a } : null; };
    obj = iArr >= 0 && (iObj < 0 || iArr < iObj) ? asArr() || asObj() : asObj() || asArr();
  }
  const arr = Array.isArray(obj) ? obj : Array.isArray(obj?.items) ? obj.items : [];
  const seen = new Set();
  const items = [];
  for (const it of arr) {
    const name = clip(String(typeof it === 'string' ? it : it?.name ?? ''), 40).replace(/[^\p{L}\p{N} '&-]/gu, '').trim();
    if (!/\p{L}{2}/u.test(name) || seen.has(name.toLowerCase())) continue;
    seen.add(name.toLowerCase());
    const c = Number(it?.confidence);
    items.push({
      name,
      qty: Math.min(50, Math.max(1, Math.round(Number(it?.qty) || 1))),
      confidence: Number.isFinite(c) ? Math.round(Math.min(1, Math.max(0, c > 1 ? c / 100 : c)) * 100) / 100 : 0.5,
    });
    if (items.length >= max) break;
  }
  return items;
}

const b64ToBytes = (b64) => { const bin = atob(b64); const u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; };
let llamaVisionAgreed = false;

async function runVision(env, b64, mode) {
  const prompt = VISION_PROMPT[mode];
  let lastErr;
  for (const m of VISION_MODELS) {
    try {
      let res;
      if (m.style === 'openai') {
        res = await env.AI.run(m.id, {
          messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${b64}` } }] }],
          max_tokens: mode === 'receipt' ? 700 : 300, temperature: 0.1,
        });
      } else {
        if (!llamaVisionAgreed) { try { await env.AI.run(m.id, { prompt: 'agree' }); } catch (_) { /* уже принято */ } llamaVisionAgreed = true; }
        res = await env.AI.run(m.id, { messages: [{ role: 'user', content: prompt }], image: [...b64ToBytes(b64)], max_tokens: 400, temperature: 0.1 });
      }
      const text = typeof res === 'string' ? res : res?.response ?? res?.result?.response ?? res?.choices?.[0]?.message?.content ?? '';
      if (text !== '' && text != null) return { items: parseVision(text, mode === 'receipt' ? 25 : 8), model: m.id };
      lastErr = new Error('empty');
    } catch (e) {
      lastErr = e;
      if (/neuron|quota|4006|3036/i.test(String(e?.message || e))) throw Object.assign(new Error('quota'), { quota: true });
    }
  }
  throw lastErr || new Error('vision failed');
}

async function handleVision(request, env, cors) {
  const raw = await request.text();
  if (raw.length > MAX_IMAGE_B64 + 2000) return json({ error: 'too_large' }, 413, cors);
  let body;
  try { body = JSON.parse(raw); } catch (_) { return json({ error: 'bad_json' }, 400, cors); }
  const deviceId = clip(body?.deviceId, 64);
  if (!/^[A-Za-z0-9-]{8,64}$/.test(deviceId)) return json({ error: 'bad_device' }, 400, cors);
  const b64 = typeof body?.image === 'string' ? body.image.replace(/^data:image\/\w+;base64,/, '') : '';
  if (b64.length < 200 || !/^[A-Za-z0-9+/=]+$/.test(b64.slice(0, 400))) return json({ error: 'no_image' }, 400, cors);
  // JPEG (FF D8) или PNG — остальное не принимаем
  if (!(b64.startsWith('/9j/') || b64.startsWith('iVBOR'))) return json({ error: 'bad_image' }, 400, cors);
  const mode = body?.mode === 'receipt' ? 'receipt' : 'food';
  if (!env.AI) return json({ error: 'offline', reason: 'no_ai_binding' }, 503, cors);
  const ip = request.headers.get('cf-connecting-ip') || 'unknown';
  if (!(await bump(env, `v:${deviceId}`, VISION_LIMIT_DEVICE)) || !(await bump(env, `vip:${ip}`, VISION_LIMIT_IP)) || !(await bump(env, 'vall', VISION_LIMIT_TOTAL))) {
    return json({ error: 'offline', reason: 'daily_limit' }, 429, cors);
  }
  try {
    const out = await runVision(env, b64, mode);
    return json({ items: out.items, model: out.model, mode }, 200, cors);
  } catch (e) {
    return json({ error: 'offline', reason: e?.quota ? 'ai_quota' : 'ai_error' }, e?.quota ? 429 : 503, cors);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('origin');
    const cors = corsHeaders(origin);

    // Браузеры с чужих сайтов не пускаем; приложение (без Origin) и наш сайт — да.
    if (origin && !ALLOWED_ORIGINS.includes(origin)) return json({ error: 'forbidden' }, 403);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

    if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/health')) {
      return json({ ok: true, service: 'nutrik', ai: Boolean(env.AI), models: MODELS, vision: VISION_MODELS.map((m) => m.id) }, 200, cors);
    }
    if (!['/chat', '/vision'].includes(url.pathname) || request.method !== 'POST') return json({ error: 'not_found' }, 404, cors);

    const client = request.headers.get('x-nutrimate-client') || '';
    if (!origin && !/^(ios|web|android|windows|macos|linux|desktop|app)/.test(client)) return json({ error: 'forbidden' }, 403);
    if (url.pathname === '/vision') return handleVision(request, env, cors);

    const raw = await request.text();
    if (raw.length > 20000) return json({ error: 'too_large' }, 413, cors);
    let body;
    try { body = JSON.parse(raw); } catch (_) { return json({ error: 'bad_json' }, 400, cors); }

    const deviceId = clip(body?.deviceId, 64);
    if (!/^[A-Za-z0-9-]{8,64}$/.test(deviceId)) return json({ error: 'bad_device' }, 400, cors);
    const messages = sanitizeMessages(body?.messages);
    if (!messages.length || messages[messages.length - 1].role !== 'user') return json({ error: 'no_message' }, 400, cors);
    if (!env.AI) return json({ error: 'offline', reason: 'no_ai_binding' }, 503, cors);

    const ip = request.headers.get('cf-connecting-ip') || 'unknown';
    if (!(await bump(env, `d:${deviceId}`, DAILY_LIMIT_DEVICE)) || !(await bump(env, `ip:${ip}`, DAILY_LIMIT_IP))) {
      return json({ error: 'offline', reason: 'daily_limit' }, 429, cors);
    }

    const lang = detectLang(messages[messages.length - 1].content, clip(body?.context?.language, 4));
    const langRule = langInstruction(lang);
    const canAct = body?.actions === true;
    const system = `${SYSTEM_PROMPT}${canAct ? ACTIONS_RULE : NO_ACTIONS_RULE}${langRule}\n\nContext about the user right now:\n${buildContext(body?.context)}`;
    try {
      const out = await runModel(env, [{ role: 'system', content: system }, ...messages]);
      const { reply, actions } = extractActions(out.reply);
      // маленькая модель путает «тоңазытқыш» (холодильник) и «мұздатқыш» (морозилка) — поправляем по словам пользователя
      const last = messages[messages.length - 1].content.toLowerCase();
      const saysFridge = /fridge|холодильник|тоңазытқыш/.test(last), saysFreezer = /freezer|морозил|мұздатқыш/.test(last);
      for (const a of actions) {
        if (a.type === 'add_freezer' && saysFridge && !saysFreezer) a.type = 'add_fridge';
        if (a.type === 'add_fridge' && saysFreezer && !saysFridge) a.type = 'add_freezer';
      }
      const model = out.model;
      if (canAct && actions.length) {
        // подтверждение напишет приложение по факту; ложное «добавил» из текста убираем
        return json({ reply: claimsAction(reply) ? '' : reply, actions, model }, 200, cors);
      }
      if (!reply || claimsAction(reply) || (canAct && PROMISES_ACTION.test(reply))) return json({ reply: HONEST_REPLY[lang], model, guarded: true, actions: [] }, 200, cors);
      return json({ reply, model, actions: [] }, 200, cors);
    } catch (e) {
      return json({ error: 'offline', reason: e?.quota ? 'ai_quota' : 'ai_error' }, e?.quota ? 429 : 503, cors);
    }
  },
};
