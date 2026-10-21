(() => {
  if (window.__maestroSiageBridge) return;
  window.__maestroSiageBridge = true;

  function payload() {
    const el = document.getElementById("maestro-siage-handoff");
    if (!el) return null;
    try { return JSON.parse(el.textContent || "{}"); }
    catch (e) { return null; }
  }

  document.addEventListener("click", (event) => {
    const botao = event.target.closest("[data-siage-open]");
    if (!botao) return;
    const handoff = payload();
    if (!handoff) return;
    event.preventDefault();
    const senha = String(handoff.senha || "").trim();
    if (senha) {
      try { chrome.storage.session.set({ senha }); } catch (e) {}
    }
    chrome.runtime.sendMessage({ tipo: "abrir-siage", handoff }, (resposta) => {
      if (chrome.runtime.lastError || !resposta || !resposta.ok) {
        window.open("https://professor.see.pb.gov.br/auth", "_blank", "noopener");
      }
    });
  });
})();
