// Permite que o motor (runner.js) leia a senha guardada só na memória (storage.session).
function liberarSessao() {
  chrome.storage.session.setAccessLevel({ accessLevel: "TRUSTED_AND_UNTRUSTED_CONTEXTS" });
}
chrome.runtime.onInstalled.addListener(liberarSessao);
chrome.runtime.onStartup.addListener(liberarSessao);
liberarSessao();

function origensDoMaestro(origin) {
  const lista = [
    origin,
    "http://127.0.0.1:3000",
    "http://localhost:3000",
    "https://cadernomaestro.com.br",
    "https://www.cadernomaestro.com.br"
  ]
    .map((s) => String(s || "").trim().replace(/\/$/, ""))
    .filter((s) => /^https?:\/\//i.test(s));
  return [...new Set(lista)];
}

async function reportarRoster(msg) {
  const corpo = JSON.stringify({
    token: msg.token || "",
    classrooms: msg.classrooms || []
  });
  for (const origem of origensDoMaestro(msg.origin)) {
    try {
      const res = await fetch(`${origem}/siage/extensao/roster`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-Maestro-Token": msg.token || ""
        },
        credentials: "include",
        body: corpo
      });
      if (res.ok) {
        const data = await res.json().catch(() => ({}));
        return { ok: true, review_url: data.review_url, status: data.status };
      }
    } catch (e) {}
  }
  return { ok: false };
}

async function reportarLivro(msg) {
  const corpo = JSON.stringify(msg.kind === "grades" ? {
    kind: "grades",
    classroom_id: msg.classroomId,
    bimester: msg.bimester,
    status: msg.status,
    message: msg.message || "",
    token: msg.token || ""
  } : {
    lesson_ids: msg.lessonIds || [],
    status: msg.status,
    message: msg.message || "",
    token: msg.token || ""
  });
  for (const origem of origensDoMaestro(msg.origin)) {
    try {
      const res = await fetch(`${origem}/siage/extensao/resultado`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-Maestro-Token": msg.token || ""
        },
        credentials: "include",
        body: corpo
      });
      if (res.ok) return { ok: true };
    } catch (e) {}
  }
  return { ok: false };
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (!msg) return;
  if (msg.tipo === "maestro-ledger") {
    reportarLivro(msg).then(sendResponse);
    return true;
  }
  if (msg.tipo === "maestro-roster") {
    reportarRoster(msg).then(sendResponse);
    return true;
  }
  if (msg.tipo === "abrir-siage") {
    const handoff = msg.handoff || {};
    const senha = String(handoff.senha || "").trim();
    const ehRoster = handoff.mode === "roster" || (handoff.job && handoff.job.kind === "roster");
    const gravar = (async () => {
      if (senha) await chrome.storage.session.set({ senha });
      if (ehRoster) {
        await chrome.storage.local.set({
          rosterHandoff: handoff,
          rosterJob: handoff.job || null
        });
        return;
      }
      await chrome.storage.local.set({ handoff, job: handoff.job || null });
      await chrome.storage.local.remove("rosterHandoff");
    })();
    gravar.then(() => {
      chrome.tabs.create({ url: "https://professor.see.pb.gov.br/auth" });
      sendResponse({ ok: true });
    });
    return true;
  }
});
