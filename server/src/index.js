// NutriMate · Nutrik AI — Cloudflare Worker (бесплатный тариф Workers Free + Workers AI).
// POST /chat  { deviceId, messages: [{role, content}], context: {...} }  →  200 { reply, model }
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
- Always answer in the same language the user wrote in.
- When suggesting what to cook, prefer the user's fridge, especially products that expire soon. Prefer recipes from the "Recipes from the app" list and name them exactly as written there. Only say a recipe is "in the app" if it is in that list; otherwise just describe a simple idea. Give grams and short steps only if asked.
- Respect disliked foods: never suggest them.
- Never give medical diagnoses, never encourage strict diets, fasting or eating far below the calorie goal. For health problems, suggest seeing a doctor.
- If the question is not about food, cooking, groceries, storage, nutrition or the app, gently bring the talk back to food in one sentence.
- Never invent the user's data: use only the context below. Do not mention that you got "context".
- You CANNOT change anything in the app: you cannot add, remove, log, freeze or move food, and you cannot edit the shopping list. Never say "I added", "I logged", "done", "добавил", "записал" or similar. The app does these actions itself when the user writes a command like "add 2 eggs to fridge", "I ate a banana", "threw away kefir", "freeze the chicken", "add milk to shopping list". If the user asks for such an action, say you can't do it from the chat and show the exact command to type.`;

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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('origin');
    const cors = corsHeaders(origin);

    // Браузеры с чужих сайтов не пускаем; приложение (без Origin) и наш сайт — да.
    if (origin && !ALLOWED_ORIGINS.includes(origin)) return json({ error: 'forbidden' }, 403);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

    if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/health')) {
      return json({ ok: true, service: 'nutrik', ai: Boolean(env.AI), models: MODELS }, 200, cors);
    }
    if (url.pathname !== '/chat' || request.method !== 'POST') return json({ error: 'not_found' }, 404, cors);

    const client = request.headers.get('x-nutrimate-client') || '';
    if (!origin && !/^(ios|web)/.test(client)) return json({ error: 'forbidden' }, 403);

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
    const langRule = `\n- Answer in ${LANG_NAMES[lang]}${lang === 'kk' ? ' (Cyrillic script, simple correct Kazakh)' : ''}.`;
    const system = `${SYSTEM_PROMPT}${langRule}\n\nContext about the user right now:\n${buildContext(body?.context)}`;
    try {
      const { reply, model } = await runModel(env, [{ role: 'system', content: system }, ...messages]);
      if (claimsAction(reply)) return json({ reply: HONEST_REPLY[lang], model, guarded: true }, 200, cors);
      return json({ reply, model }, 200, cors);
    } catch (e) {
      return json({ error: 'offline', reason: e?.quota ? 'ai_quota' : 'ai_error' }, e?.quota ? 429 : 503, cors);
    }
  },
};
