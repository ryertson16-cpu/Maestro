// Permite que o motor (runner.js) leia a senha guardada só na memória (storage.session).
function liberarSessao() {
  chrome.storage.session.setAccessLevel({ accessLevel: "TRUSTED_AND_UNTRUSTED_CONTEXTS" });
}
chrome.runtime.onInstalled.addListener(liberarSessao);
chrome.runtime.onStartup.addListener(liberarSessao);
liberarSessao();
