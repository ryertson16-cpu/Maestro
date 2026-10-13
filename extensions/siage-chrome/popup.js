const fileInput = document.getElementById("payload-file");
const fillButton = document.getElementById("fill-button");
const payloadStatus = document.getElementById("payload-status");
const fillResult = document.getElementById("fill-result");

let payload = null;

chrome.storage.local.get("siagePayload").then((stored) => {
  if (!stored.siagePayload) return;

  payload = stored.siagePayload;
  payloadStatus.textContent = describePayload(payload);
  fillButton.disabled = false;
});

fileInput.addEventListener("change", async (event) => {
  const file = event.target.files[0];
  fillResult.textContent = "";

  if (!file) return;

  try {
    payload = JSON.parse(await file.text());
    await chrome.storage.local.set({ siagePayload: payload });
    payloadStatus.textContent = describePayload(payload);
    fillButton.disabled = false;
  } catch (error) {
    payload = null;
    fillButton.disabled = true;
    payloadStatus.textContent = "JSON inválido. Exporte de novo pelo Maestro.";
  }
});

fillButton.addEventListener("click", async () => {
  fillResult.textContent = "";

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  if (!tab?.id || !tab.url?.includes("professor.see.pb.gov.br")) {
    fillResult.textContent = "Abra o SIAGE nesta aba e tente de novo.";
    return;
  }

  try {
    const response = await sendFill(tab.id, payload);
    fillResult.textContent = response?.message || "Não foi possível preencher esta página.";
  } catch (error) {
    fillResult.textContent = "Recarregue a aba do SIAGE (F5) e clique de novo em Preencher esta página.";
  }
});

async function sendFill(tabId, data) {
  try {
    return await chrome.tabs.sendMessage(tabId, {
      type: "SIAGE_FILL",
      payload: data
    });
  } catch (_error) {
    await chrome.scripting.executeScript({
      target: { tabId },
      files: ["page.js"],
      world: "MAIN"
    });
    await chrome.scripting.executeScript({
      target: { tabId },
      files: ["content.js"]
    });

    return await chrome.tabs.sendMessage(tabId, {
      type: "SIAGE_FILL",
      payload: data
    });
  }
}

function describePayload(data) {
  const classroom = data.classroom?.name || "turma";
  const date = data.lesson?.date_br || "";
  return `Pronto: ${classroom}${date ? ` — ${date}` : ""}.`;
}
