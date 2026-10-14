// Motor da extensão: roda dentro do SIAGE (professor.see.pb.gov.br).
// O trabalho fica salvo em chrome.storage, então continua mesmo se a página recarregar.
(() => {
  if (window.__siageRunner) return;
  window.__siageRunner = true;

  const norm = (s) => (s || "").toString().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\s+/g, " ").trim().toLowerCase();
  const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
  const visivel = (el) => !!el && !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  const q = (sel, raiz = document) => [...raiz.querySelectorAll(sel)];
  async function aguardar(fn, ms = 8000) {
    const fim = Date.now() + ms;
    while (Date.now() < fim) { const r = fn(); if (r) return r; await esperar(150); }
    return null;
  }
  const botoes = () => q("button, a.btn, [role=button]").filter((b) => visivel(b) && !b.closest("#siage-fila-painel"));
  const botaoComTexto = (re) => botoes().find((b) => re.test(norm(b.textContent || b.value)));
  function campo(re) {
    const lab = q("label").filter(visivel).find((l) => {
      if (l.closest("#siage-fila-painel")) return false;
      const t = norm(l.textContent);
      return t.length < 24 && re.test(t) && !/obrigatorio/.test(t);
    });
    if (!lab) return null;
    return lab.closest(".form-group, app-field, .p-field, .field, .p-formgroup, mat-form-field, p-dropdown, p-multiselect, ng-select") || lab.parentElement;
  }
  const naTelaDeCadastro = () => !!botaoComTexto(/^salvar/);
  function botaoNovoRegistro() {
    const porTexto = botaoComTexto(/registrar aula/) ||
      botaoComTexto(/registrar frequencia/) ||
      botaoComTexto(/novo registro/) ||
      botaoComTexto(/^novo$/) ||
      botaoComTexto(/incluir/) ||
      botaoComTexto(/adicionar/) ||
      botaoComTexto(/cadastrar/);
    if (porTexto) return porTexto;
    return q("button, a, [role=button], p-button").filter(visivel).find((b) => {
      if (b.closest("#siage-fila-painel")) return false;
      const rotulo = `${b.title || ""} ${b.getAttribute("aria-label") || ""} ${b.textContent || ""} ${b.className || ""}`;
      return /novo|incluir|adicionar|registrar|cadastrar|pi-plus|fa-plus|p-button-icon-only/i.test(rotulo);
    });
  }
  const naUrlRegistroAula = () => /registro-aula|registro_aula/.test(location.pathname);
  const naLista = () => !naTelaDeCadastro() && !!(botaoComTexto(/registrar frequencia/) || botaoNovoRegistro());
  function mensagemDoSistema() {
    const m = q(".toast-message, .toast-body, .ui-toast-detail, .ui-toast-summary, .p-toast-detail, .swal2-html-container, .swal2-title, .alert, .invalid-feedback, .ui-message-error")
      .filter(visivel).map((e) => e.textContent.trim()).filter(Boolean);
    return m.join(" ").slice(0, 160);
  }


  const URL_LISTAGEM = location.origin + "/diario/minhas-turmas/listagem-turmas";
  const dataBR = (iso) => iso.split("-").reverse().join("/");
  const lerJob = async () => (await chrome.storage.local.get("job")).job;
  const gravarJob = (job) => chrome.storage.local.set({ job });
  function statusDoLivro(estado) {
    if (estado === "ok") return "verified";
    if (estado === "ja") return "already_registered";
    return "failed";
  }
  function avisarMaestro(job, aula, status) {
    if (!job || job.teste) return;
    const ids = (aula.maestroIds || []).map((x) => parseInt(x, 10)).filter((n) => n > 0);
    if (!ids.length) return;
    try {
      chrome.runtime.sendMessage({
        tipo: "maestro-ledger",
        lessonIds: ids,
        status,
        message: aula.msg || "",
        token: job.token || "",
        origin: job.origin || ""
      }, () => void chrome.runtime.lastError);
    } catch (e) {}
  }
  async function lerSenha() {
    try { return (await chrome.storage.session.get("senha")).senha || ""; } catch (e) { return ""; }
  }

  function clicarNativo(el) {
    if (!el) return false;
    const alvo = el.closest("button, a, [role=button]") || el;
    try {
      alvo.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true }));
      alvo.dispatchEvent(new PointerEvent("pointerup", { bubbles: true, cancelable: true }));
    } catch (e) {}
    alvo.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true, view: window }));
    alvo.dispatchEvent(new MouseEvent("mouseup", { bubbles: true, cancelable: true, view: window }));
    alvo.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
    if (typeof alvo.click === "function") alvo.click();
    return true;
  }

  function botaoPorRotulo(re) {
    return q("button, a, [role=button], .p-button, p-button, input[type=submit]").filter(visivel)
      .find((b) => re.test(norm(b.textContent || b.value || b.getAttribute("aria-label") || "")));
  }

  function ehTelaAnoLetivo() {
    const t = (document.body?.innerText || "").slice(0, 3000);
    if (!/ano letivo/i.test(t) || !/matr[ií]cula/i.test(t)) return false;
    if (q("input[type=password]").some(visivel)) return false;
    return !!botaoPorRotulo(/selecionar/);
  }

  function ehTelaDeLogin() {
    if (ehTelaAnoLetivo()) return false;
    const t = (document.body?.innerText || "").slice(0, 1200);
    if (q("input[type=password]").some(visivel) && (/fa[cç]a login/i.test(t) || /\/auth(\/|$)/i.test(location.pathname))) return true;
    return /fa[cç]a login/i.test(t) && q("input[type=password]").some(visivel);
  }

  function campoUsuarioLogin() {
    return q("input").filter(visivel).find((el) =>
      el.type !== "password" && el.type !== "hidden" && el.type !== "checkbox" && el.type !== "submit" && el.type !== "button"
    );
  }

  function preencherCampoNativo(campo, valor) {
    if (!campo) return;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")?.set;
    if (setter) setter.call(campo, valor);
    else campo.value = valor;
    for (const tipo of ["input", "keyup", "change", "blur"]) {
      campo.dispatchEvent(new Event(tipo, { bubbles: true }));
    }
  }

  function pedirSenhaPainel() {
    return new Promise((resolve) => {
      let box = document.getElementById("siage-login-senha");
      if (box) box.remove();
      box = document.createElement("div");
      box.id = "siage-login-senha";
      box.style.cssText = "position:fixed;right:16px;bottom:16px;z-index:2147483647;width:340px;background:#fff;color:#1f2937;border:1px solid #d1d5db;border-radius:10px;box-shadow:0 8px 24px rgba(0,0,0,.2);font:13px system-ui,sans-serif;padding:12px";
      box.innerHTML = `<b>Senha do SIAGE</b>
        <p style="margin:6px 0;color:#4b5563">O Maestro não guarda essa senha. Digite aqui para entrar e enviar a frequência.</p>
        <input id="siage-login-campo" type="password" autocomplete="off" style="width:100%;box-sizing:border-box;padding:8px;margin:4px 0 8px">
        <button type="button" id="siage-login-ok" style="width:100%;padding:8px;border:0;border-radius:8px;background:#15803d;color:#fff;font-weight:600;cursor:pointer">Entrar no SIAGE</button>`;
      document.body.appendChild(box);
      const campo = box.querySelector("#siage-login-campo");
      const enviar = async () => {
        const senha = (campo.value || "").trim();
        if (!senha) return;
        box.remove();
        resolve(senha);
      };
      box.querySelector("#siage-login-ok").onclick = enviar;
      campo.addEventListener("keydown", (ev) => { if (ev.key === "Enter") enviar(); });
      campo.focus();
    });
  }

  async function preencherLogin(handoff) {
    const cpf = String(handoff.cpf || "").replace(/\D/g, "");
    const user = campoUsuarioLogin();
    if (user && cpf) preencherCampoNativo(user, cpf);
    let senha = String(handoff.senha || "").trim();
    if (!senha) senha = await lerSenha();
    if (!senha) senha = await pedirSenhaPainel();
    if (!senha) return false;
    await chrome.storage.session.set({ senha });
    const pass = q("input[type=password]").find(visivel);
    if (pass) preencherCampoNativo(pass, senha);
    await esperar(200);
    const acessar = botaoComTexto(/acessar|entrar/) ||
      q("button").filter(visivel).find((b) => /acessar|entrar/i.test(b.textContent || b.value || ""));
    if (acessar && !acessar.disabled) clicarNativo(acessar);
    const job = await lerJob();
    if (job && job.status === "aguardando-login") {
      job.status = "rodando";
      await gravarJob(job);
    }
    await aguardar(() => ehTelaAnoLetivo() || !ehTelaDeLogin(), 20000);
    return true;
  }

  function rotuloTurma(nome) {
    const s = String(nome || "").trim();
    if (/s[eé]rie|t[eé]cnic|qualifica|integrado/i.test(s)) return s;
    return s.replace(/^(\d+)\s*[ªºa°]?\s+/i, "$1ª SÉRIE ");
  }

  // "2ª SÉRIE H" / "2ª H" / "3ª SÉRIE N - INFORMÁTICA"
  function reTurma(turma) {
    const n = norm(rotuloTurma(turma));
    let m = n.match(/(\d+)\s*[ªaº°o]?\s*serie\s*-?\s*([a-z])\b/);
    if (!m) m = n.match(/(\d+)\s*[ªaº°o]?\s+([a-z])\b/);
    if (!m) return new RegExp(n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
    return new RegExp(`(^|[^0-9])${m[1]}\\s*[ªaº°o]?\\s*(serie\\s*)?-?\\s*${m[2]}([^a-z]|$)`);
  }
  // "Práticas Integradoras I" não pode casar com "Práticas Integradoras II"
  const APELIDOS = { isc: "Inovação Social e Científica" };
  const nomeComponente = (c) => APELIDOS[norm(c)] || c;
  const reComp = (comp) => new RegExp(`(^|[^a-z])${norm(comp).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}([^a-z]|$)`);

  function cabecalhoTurma() {
    return q("h1, h2, h3, h4, h5").map((e) => e.innerText || e.textContent).join(" | ");
  }

  function paginaDaTurma(grupo) {
    const bloco = cabecalhoTurma() || (document.body?.innerText || "").slice(0, 1800);
    const t = norm(bloco);
    if (!reTurma(grupo.turma).test(t)) return false;
    if (!grupo.componente) return true;
    const compTxt = q("strong, b, span, p, div").filter(visivel)
      .filter((s) => /componente curricular/.test(norm(s.textContent)))
      .map((s) => norm((s.parentElement || s).innerText || s.textContent)).join(" | ") || t;
    return reComp(nomeComponente(grupo.componente)).test(compTxt) || reComp(nomeComponente(grupo.componente)).test(t);
  }
  const naPaginaDeFrequencia = () => /\/(frequencia|registro-aula|registro_aula)(\/|$)/i.test(location.pathname);
  const naAbaRegistroDeAula = () => {
    if (naUrlRegistroAula()) return true;
    const titulo = q("h1, h2, h3, .breadcrumb, nav").map((e) => e.innerText || e.textContent).join(" ");
    if (/registro de aula/.test(norm(titulo))) return true;
    return q("a, button, li, .nav-link, [role=tab]").some((a) =>
      visivel(a) && /registro de aula/.test(norm(a.textContent)) &&
      (/active|current|selected/.test(`${a.className} ${a.parentElement?.className || ""}`) || a.getAttribute("aria-selected") === "true")
    );
  };
  function abaAtiva(re) {
    return q("a, button, li, .nav-link, [role=tab]").some((a) =>
      visivel(a) && re.test(norm(a.textContent)) &&
      (/active|current|selected/.test(`${a.className} ${a.parentElement?.className || ""}`) || a.getAttribute("aria-selected") === "true")
    );
  }
  function naAbaFrequencia() {
    if (/\/frequencia(\/|$)/i.test(location.pathname)) return true;
    const titulo = q("h1, h2, h3, .breadcrumb, nav").map((e) => e.innerText || e.textContent).join(" ");
    if (/frequencia/.test(norm(titulo)) && !/registro de aula/.test(norm(titulo))) return true;
    return abaAtiva(/^frequencia$/);
  }
  function naFormularioFrequencia() {
    const t = norm((document.body?.innerText || "").slice(0, 3500));
    return /informacoes sobre a aula/.test(t) && !!(campo(/^data/) || campo(/^periodo/) || campo(/^tempo/));
  }
  function botaoRegistrarFrequencia() {
    return botaoComTexto(/registrar frequencia/) ||
      q("button, a, [role=button]").filter(visivel).find((b) => {
        if (b.closest("#siage-fila-painel")) return false;
        return /registrar frequencia/.test(norm(`${b.textContent || ""} ${b.getAttribute("aria-label") || ""} ${b.title || ""}`));
      });
  }

  function ehHubDiario() {
    const t = (document.body?.innerText || "").slice(0, 4000);
    return /visualizar minhas turmas/i.test(t) && /plano de ensino/i.test(t);
  }

  function ehListagemTurmas() {
    if (/listagem-turmas\/?$/.test(location.pathname)) return true;
    const cab = q("th, thead td, [role=columnheader]").map((el) => norm(el.textContent)).join(" ");
    return /turma/.test(cab) && /componente/.test(cab) && /acao/.test(cab);
  }

  function ehPaginaTurmaAberta() {
    if (/\/turma\//.test(location.pathname)) return true;
    return q("a, button, .nav-link, [role=tab]").some((a) =>
      visivel(a) && /registro de aula|registro de avaliacoes|^frequencia$/.test(norm(a.textContent))
    );
  }

  function clicarNav(re) {
    const el = q("a, button, .nav-link, [role=tab], [role=link]").filter(visivel)
      .find((e) => re.test(norm(e.textContent || e.getAttribute("aria-label") || "")));
    if (!el) return false;
    clicarNativo(el);
    return true;
  }

  function botaoAcessarDoCard(tituloRe) {
    const titulo = q("h2, h3, h4, h5, strong, p, span, div").filter(visivel)
      .find((el) => tituloRe.test(norm(el.textContent)) && String(el.textContent || "").trim().length < 80);
    if (!titulo) return null;
    let raiz = titulo;
    for (let i = 0; i < 8 && raiz.parentElement; i++) {
      raiz = raiz.parentElement;
      const btn = q("button, a", raiz).find((b) => visivel(b) && /^acessar$/.test(norm(b.textContent)));
      if (btn) return btn;
    }
    return null;
  }

  function ehTelaDeAvaliacoes() {
    const t = document.body?.innerText || "";
    return /1[ªa]\s*unidade/i.test(t) && /rec\s*\/?\s*rep/i.test(t);
  }

  function chegouNoDiario() {
    return ehListagemTurmas() || ehPaginaTurmaAberta() || naPaginaDeFrequencia() || naLista() || naTelaDeCadastro() || ehTelaDeAvaliacoes();
  }

  async function entrarNoDiario() {
    for (let i = 0; i < 24; i++) {
      if (ehTelaDeLogin()) return "login";
      if (chegouNoDiario()) return "ok";

      if (ehTelaAnoLetivo()) {
        const btn = botaoPorRotulo(/^selecionar$/) || botaoPorRotulo(/selecionar/) || botaoComTexto(/selecionar/);
        if (btn && !btn.disabled) clicarNativo(btn);
        await aguardar(() => !ehTelaAnoLetivo() || ehHubDiario() || chegouNoDiario(), 12000);
        await esperar(400);
        continue;
      }

      if (ehHubDiario()) {
        const btn = botaoAcessarDoCard(/visualizar minhas turmas/)
          || botoes().find((b) => /^acessar$/.test(norm(b.textContent)));
        if (btn) clicarNativo(btn);
        await aguardar(() => ehListagemTurmas() || chegouNoDiario(), 12000);
        await esperar(400);
        continue;
      }

      if (clicarNav(/^diario$/)) {
        await aguardar(() => ehHubDiario() || ehListagemTurmas() || chegouNoDiario(), 12000);
        await esperar(400);
        continue;
      }

      if (!/listagem-turmas/.test(location.pathname) && i > 2) {
        location.href = URL_LISTAGEM;
        return "navegando";
      }
      await esperar(500);
    }
    return chegouNoDiario() ? "ok" : "navegando";
  }

  function botaoPrancheta(linha) {
    const celulas = q("td", linha);
    const acao = celulas[celulas.length - 1] || linha;
    const porTitulo = q("button, a", acao).find((b) => {
      const rotulo = `${b.title || ""} ${b.getAttribute("aria-label") || ""} ${b.textContent || ""}`;
      return /visualizar|diario|prancheta|clipboard|abrir/i.test(rotulo);
    });
    if (porTitulo) return porTitulo;
    const icone = acao.querySelector("#btn-visualizar, button[title=Visualizar], a[title=Visualizar], i, svg, span.pi, span.fa, span.p-button-icon");
    if (icone) return icone.closest("button, a") || icone;
    return q("button, a", acao).find(visivel) || q("button, a", linha).find(visivel);
  }

  function contarEstados(job) {
    const aulas = (job.grupos || []).flatMap((g) => g.aulas || []);
    return {
      total: aulas.length,
      ok: aulas.filter((a) => a.estado === "ok").length,
      ja: aulas.filter((a) => a.estado === "ja").length,
      erro: aulas.filter((a) => a.estado === "erro").length,
      falta: aulas.filter((a) => a.estado === "pendente")
    };
  }

  function aulaApareceNaLista(aula) {
    const br = norm(dataBR(aula.data));
    const linhas = q("table tbody tr, .p-datatable-tbody > tr").filter((tr) => visivel(tr) && !tr.closest("#siage-fila-painel"));
    return linhas.some((tr) => {
      const txt = norm(tr.innerText || tr.textContent);
      if (!txt.includes(br)) return false;
      const tempos = aula.tempos || [];
      if (!tempos.length) return true;
      return tempos.some((t) => new RegExp(`(^|[^0-9])${t}([^0-9]|$)`).test(txt));
    });
  }

  async function marcarJaNaTela(job, gi) {
    const grupo = job.grupos[gi];
    if (!grupo || !grupo.aulas) return;
    let mudou = false;
    grupo.aulas.forEach((aula) => {
      if (aula.estado !== "pendente") return;
      if (!aulaApareceNaLista(aula)) return;
      aula.estado = "ja";
      aula.msg = "já consta na Frequência";
      avisarMaestro(job, aula, "already_registered");
      mudou = true;
    });
    if (mudou) await gravarJob(job);
  }

  // ---------- Painel ----------
  let painel;
  function desenharPainel(job, atual) {
    if (!painel || !document.body.contains(painel)) {
      painel = document.createElement("div");
      painel.id = "siage-fila-painel";
      painel.style.cssText = "position:fixed;right:16px;bottom:16px;z-index:2147483647;width:360px;max-height:70vh;overflow:auto;background:#fff;color:#1f2937;border:1px solid #d1d5db;border-radius:10px;box-shadow:0 8px 24px rgba(0,0,0,.2);font:13px system-ui,sans-serif;padding:12px;pointer-events:none";
      document.body.appendChild(painel);
    }
    const rodando = job.status === "rodando";
    const c = contarEstados(job);
    const linhas = job.grupos.map((g) => {
      const ok = g.aulas.filter((a) => a.estado === "ok").length;
      const ja = g.aulas.filter((a) => a.estado === "ja").length;
      const erro = g.aulas.filter((a) => a.estado === "erro").length;
      const falta = g.aulas.filter((a) => a.estado === "pendente").length;
      const nome = g.turma ? `${g.turma}${g.componente ? " · " + g.componente : ""}` : "Turma aberta";
      return `<div style="padding:3px 0;border-top:1px solid #f3f4f6">${nome}: <b style="color:#15803d">${ok} feitas</b>${ja ? ` · <b style="color:#5b4bdb">${ja} já no SIAGE</b>` : ""}${falta ? ` · <b>${falta} faltam</b>` : ""}${erro ? ` · <b style="color:#b91c1c">${erro} falhou</b>` : ""} <span style="color:#6b7280">/ ${g.aulas.length}</span></div>`;
    }).join("");
    const faltaTxt = c.falta.slice(0, 6).map((a) => dataBR(a.data) + (a.tempos && a.tempos.length ? " t." + a.tempos.join(",") : "")).join(" · ");
    const erros = job.grupos.flatMap((g) => g.aulas.filter((a) => a.estado === "erro").map((a) => `${g.turma || ""} ${dataBR(a.data)}: ${a.msg}`)).slice(-8);
    const jaAvisos = job.grupos.flatMap((g) => g.aulas.filter((a) => a.estado === "ja").map((a) => `${g.turma || ""} ${dataBR(a.data)}: ${a.msg || "já consta na Frequência"}`)).slice(-8);
    painel.innerHTML = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
      <b>${rodando ? "Frequência" : job.status === "concluido" ? "Concluído" : "Parado"}</b>
      <button type="button" id="siage-fila-botao" style="pointer-events:auto;border:1px solid ${rodando ? "#b91c1c" : "#6b7280"};color:${rodando ? "#b91c1c" : "#374151"};background:#fff;border-radius:6px;padding:2px 8px;cursor:pointer">${rodando ? "Parar" : "Fechar"}</button></div>
      <div style="margin-bottom:6px;font-size:12px;color:#374151"><b>${c.ok + c.ja}</b> de <b>${c.total}</b> · ${c.ok} feitas agora · ${c.ja} já estavam · ${c.falta.length} faltam</div>
      <div style="color:#1d4ed8;margin-bottom:6px">${atual || ""}</div>${linhas}
      ${c.falta.length ? `<div style="margin-top:6px;color:#4b5563;font-size:12px">Ainda faltam: ${faltaTxt}${c.falta.length > 6 ? "…" : ""}</div>` : ""}
      ${jaAvisos.length ? `<div style="margin-top:6px;color:#5b4bdb;font-size:12px">${jaAvisos.map((e) => "● " + e.replace(/</g, "&lt;")).join("<br>")}</div>` : ""}
      ${erros.length ? `<div style="margin-top:6px;color:#b91c1c;font-size:12px">${erros.map((e) => "✖ " + e.replace(/</g, "&lt;")).join("<br>")}</div>` : ""}`;
    painel.querySelector("#siage-fila-botao").onclick = async () => {
      if (rodando) { const j = await lerJob(); j.status = "parado"; await gravarJob(j); desenharPainel(j, "Parando depois da aula atual…"); }
      else painel.remove();
    };
  }

  // ---------- Abrir a turma ----------
  function linhasListagemTurmas() {
    return q("tbody tr, .p-datatable-tbody > tr").filter((tr) => visivel(tr) && !tr.closest("#siage-fila-painel") && q("td", tr).length >= 2);
  }

  async function acharNaListagem(grupo) {
    const rt = reTurma(grupo.turma);
    const chave = "siageBusca:" + norm(grupo.turma) + "|" + norm(grupo.componente);
    sessionStorage.removeItem(chave);
    const primeira = q(".ngx-pagination li a, .pagination li a, pagination-controls a").find((a) => visivel(a) && norm(a.textContent).replace(/page/g, "").trim() === "1");
    if (primeira && !primeira.closest("li.current")) {
      primeira.click();
      await esperar(1200);
    }
    await aguardar(() => linhasListagemTurmas().length > 0, 12000);
    for (let paginas = 1; paginas < 30; paginas++) {
      await aguardar(() => linhasListagemTurmas().length > 0, 8000);
      const candidatos = linhasListagemTurmas().filter((tr) => {
        const celulas = q("td", tr).map((td) => norm(td.innerText || td.textContent));
        const textoLinha = celulas.join(" ");
        const turmaOk = celulas.some((c) => rt.test(c)) || rt.test(textoLinha);
        const compOk = !grupo.componente || celulas.some((c) => c === norm(nomeComponente(grupo.componente))) || reComp(nomeComponente(grupo.componente)).test(textoLinha);
        return turmaOk && compOk;
      });
      if (candidatos.length) { sessionStorage.removeItem(chave); return candidatos[0]; }
      const proxima = q("li.pagination-next:not(.disabled) a, .pagination-next:not(.disabled) a, a[aria-label*='Next'], a[aria-label*='Próxima']").find(visivel);
      if (!proxima) { sessionStorage.removeItem(chave); return null; }
      sessionStorage.setItem(chave, String(paginas + 1));
      const antes = linhasListagemTurmas().map((tr) => tr.innerText).join("|");
      proxima.click();
      await aguardar(() => linhasListagemTurmas().map((tr) => tr.innerText).join("|") !== antes, 5000);
      await esperar(800);
    }
    sessionStorage.removeItem(chave);
    return null;
  }

  function naDestinoTurma(grupo, destino) {
    if (!paginaDaTurma(grupo) && destino !== "avaliacoes") return false;
    if (destino === "avaliacoes") return ehTelaDeAvaliacoes();
    return /\/frequencia/i.test(location.pathname) && (
      naLista() || naTelaDeCadastro() || naFormularioFrequencia() || naAbaFrequencia() || !!botaoRegistrarFrequencia()
    );
  }

  async function abrirAbaDaTurma(grupo, destino) {
    if (destino === "avaliacoes") {
      if (ehTelaDeAvaliacoes()) return "ok";
      if (clicarNav(/registro de avaliacoes/)) {
        await aguardar(() => ehTelaDeAvaliacoes(), 8000);
      }
      return "ok";
    }
    const id = grupo.turmaId || (location.pathname.match(/\/turma\/([0-9a-f-]{8,})/i) || [])[1];
    if (id && !/\/frequencia/i.test(location.pathname)) {
      location.href = `${URL_LISTAGEM}/turma/${id}/frequencia`;
      return "navegando";
    }
    if (naLista() || naTelaDeCadastro() || naFormularioFrequencia() || naAbaFrequencia() || botaoRegistrarFrequencia()) return "ok";
    const aba = q("a#frequencia, a.nav-link, [role=tab]").find((a) => visivel(a) && /^frequencia$/.test(norm(a.textContent)));
    if (aba) {
      clicarPaginaEl(aba);
      await aguardar(() => naLista() || naAbaFrequencia() || naFormularioFrequencia(), 10000);
      return "ok";
    }
    if (id) {
      location.href = `${URL_LISTAGEM}/turma/${id}/frequencia`;
      return "navegando";
    }
    return paginaDaTurma(grupo) ? "ok" : "errada";
  }

  async function abrirTurma(job, gi, destino = "frequencia") {
    const grupo = job.grupos[gi];
    if (naDestinoTurma(grupo, destino)) return "ok";

    const passo = await entrarNoDiario();
    if (passo === "login" || passo === "navegando") return "navegando";

    if (ehPaginaTurmaAberta() && !paginaDaTurma(grupo) && !ehListagemTurmas()) {
      location.href = URL_LISTAGEM;
      return "navegando";
    }

    if (ehPaginaTurmaAberta() && paginaDaTurma(grupo)) {
      return abrirAbaDaTurma(grupo, destino);
    }

    const chaveAbrindo = "siageAbrindo:" + norm(grupo.turma) + "|" + norm(grupo.componente);
    const idNaUrl = (location.pathname.match(/\/turma\/([0-9a-f-]{8,})/i) || [])[1];
    if (idNaUrl && !grupo.turmaId) {
      await aguardar(() => paginaDaTurma(grupo), 6000);
      if (paginaDaTurma(grupo) || sessionStorage.getItem(chaveAbrindo)) {
        grupo.turmaId = idNaUrl;
        sessionStorage.removeItem(chaveAbrindo);
        await gravarJob(job);
      }
    }
    if (grupo.turmaId && destino === "frequencia") {
      if (!/\/frequencia/i.test(location.pathname)) {
        location.href = `${URL_LISTAGEM}/turma/${grupo.turmaId}/frequencia`;
        return "navegando";
      }
      await aguardar(() => paginaDaTurma(grupo) || naLista() || naTelaDeCadastro(), 10000);
      if (paginaDaTurma(grupo) || naLista() || naTelaDeCadastro()) return "ok";
    }
    if (grupo.turmaId && ehPaginaTurmaAberta() && paginaDaTurma(grupo)) {
      return abrirAbaDaTurma(grupo, destino);
    }
    if (!ehListagemTurmas()) {
      const extra = await entrarNoDiario();
      if (extra === "navegando" || extra === "login") return "navegando";
      if (!ehListagemTurmas()) {
        location.href = URL_LISTAGEM;
        return "navegando";
      }
    }
    const linha = await acharNaListagem(grupo);
    if (!linha) return "nao-achou";
    const link = botaoPrancheta(linha)
      || linha.querySelector("#btn-visualizar, button[title=Visualizar]")
      || q("a[href*='/turma/']", linha)[0]
      || q("button, a", linha)[0]
      || linha;
    sessionStorage.setItem(chaveAbrindo, "1");
    link.click();
    const abriu = await aguardar(() => ehPaginaTurmaAberta() || (location.pathname.match(/\/turma\/([0-9a-f-]{8,})/i) || [])[1], 10000);
    if (!abriu) return "nao-abriu";
    const id = (location.pathname.match(/\/turma\/([0-9a-f-]{8,})/i) || [])[1];
    if (id) grupo.turmaId = id;
    sessionStorage.removeItem(chaveAbrindo);
    await gravarJob(job);
    return abrirAbaDaTurma(grupo, destino);
  }

  async function irParaAvaliacoes(handoff) {
    const lista = Array.isArray(handoff && handoff.grades) ? handoff.grades : [];
    if (!lista.length) return "ok";
    if (ehTelaDeAvaliacoes()) return "ok";
    const payload = lista[0];
    const grupo = {
      turma: payload?.classroom?.name || "",
      componente: payload?.course?.name || payload?.componente || ""
    };
    const job = await lerJob() || { grupos: [grupo], status: "rodando" };
    if (!job.grupos || !job.grupos.length) job.grupos = [grupo];
    const gi = job.grupos.findIndex((g) => reTurma(g.turma).test(norm(grupo.turma))) ;
    const idx = gi >= 0 ? gi : 0;
    if (!job.grupos[idx].turma) job.grupos[idx] = { ...job.grupos[idx], ...grupo };
    return abrirTurma(job, idx, "avaliacoes");
  }

  const MESES_PT = ["janeiro","fevereiro","marco","abril","maio","junho","julho","agosto","setembro","outubro","novembro","dezembro"];
  const MESES_TELA = ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"];

  function dialogRegistroAula() {
    const tenta = q(".p-dialog, .ui-dialog, .modal, [role=dialog], .p-dialog-content, .cdk-overlay-pane, .p-overlaypanel");
    const hit = tenta.filter(visivel).find((d) =>
      !d.closest("#siage-fila-painel") && /selecione um mes e uma data/.test(norm(d.innerText || "").slice(0, 900))
    );
    if (hit) return hit;
    return q("div").filter(visivel).find((el) => {
      const t = el.innerText || "";
      return /selecione um mes e uma data para o registro de aula/i.test(t) && t.length < 5000;
    });
  }

  function ehModalMesData() {
    const t = norm((dialogRegistroAula() || document.body).innerText || "").slice(0, 2500);
    return /selecione um mes e uma data/.test(t);
  }

  function folhasComTexto(texto, raiz) {
    const alvo = norm(texto);
    const acc = [];
    q("*", raiz || document.body).forEach((el) => {
      if (el.closest("#siage-fila-painel")) return;
      const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).filter(Boolean).join(" ");
      if (own && norm(own) === alvo) acc.push(el);
    });
    return acc.filter(visivel);
  }

  function clicarNaPagina(x, y) {
    window.postMessage({ __siage: 1, acao: "click", x, y }, "*");
  }
  function digitarNaPagina(texto) {
    window.postMessage({ __siage: 1, acao: "type", texto }, "*");
  }
  function enterNaPagina() {
    window.postMessage({ __siage: 1, acao: "enter" }, "*");
  }
  function pedirPagina(acao, extra = {}, ms = 12000) {
    return new Promise((resolve) => {
      const fn = (ev) => {
        if (ev.source !== window || !ev.data || ev.data.__siage !== 2 || ev.data.acao !== acao + ":ok") return;
        window.removeEventListener("message", fn);
        resolve(ev.data.ok);
      };
      window.addEventListener("message", fn);
      window.postMessage({ __siage: 1, acao, ...extra }, "*");
      setTimeout(() => { window.removeEventListener("message", fn); resolve(false); }, ms);
    });
  }
  function pedirPaginaDetalhe(acao, extra = {}, ms = 20000) {
    return new Promise((resolve) => {
      const fn = (ev) => {
        if (ev.source !== window || !ev.data || ev.data.__siage !== 2 || ev.data.acao !== acao + ":ok") return;
        window.removeEventListener("message", fn);
        resolve(ev.data);
      };
      window.addEventListener("message", fn);
      window.postMessage({ __siage: 1, acao, ...extra }, "*");
      setTimeout(() => { window.removeEventListener("message", fn); resolve({ ok: false, aviso: "tempo esgotado" }); }, ms);
    });
  }
  function recusarCancelarPreenchimento() {
    const t = norm(document.body.innerText || "");
    if (!/cancelar o preenchimento/.test(t)) return false;
    const nao = botoes().find((b) => /^nao$/.test(norm(b.textContent)));
    if (nao) { clicarNativo(nao); return true; }
    return false;
  }
  async function fecharAlertaSiage() {
    const t = norm(document.body.innerText || "");
    if (!/nao e possivel selecionar uma data posterior|data posterior a data atual/.test(t)) return false;
    const ok = botoes().find((b) => /^(ok|sim)$/.test(norm(b.textContent))) || q(".swal2-confirm, .p-dialog button").find(visivel);
    if (ok) clicarNativo(ok);
    await pedirPagina("fecharAlerta", {}, 3000);
    await esperar(400);
    return true;
  }

  function clicarPonto(el, fracX, fracY) {
    if (!el) return false;
    clicarNativo(el);
    const r = el.getBoundingClientRect();
    const x = r.left + Math.max(2, r.width * fracX);
    const y = r.top + Math.max(2, r.height * fracY);
    clicarNaPagina(x, y);
    return true;
  }

  function clicarCentro(el) {
    if (!el) return false;
    clicarNativo(el);
    return clicarPonto(el, 0.5, 0.5);
  }

  // Combo do campo Mês (caixa com seta). Não é o título "Outubro" do calendário.
  function widgetMes() {
    const raiz = dialogRegistroAula() || document.body;
    const lab = q("label", raiz).filter(visivel).find((l) => /^mes/.test(norm(l.textContent)) && norm(l.textContent).length < 40);
    const combos = q("ng-select, p-dropdown, .ng-select, .p-dropdown, [role=combobox]", raiz).filter(visivel)
      .filter((el) => !el.closest("#siage-fila-painel"));
    if (lab && combos.length) {
      const lr = lab.getBoundingClientRect();
      combos.sort((a, b) => Math.abs(a.getBoundingClientRect().top - lr.bottom) - Math.abs(b.getBoundingClientRect().top - lr.bottom));
      return combos[0];
    }
    if (lab) {
      const grupo = lab.parentElement;
      const input = grupo && q("input:not([type=hidden]):not([type=checkbox]), select, [role=combobox]", grupo).find(visivel);
      if (input) return input.closest("ng-select, p-dropdown, .p-dropdown, .ng-select") || input.parentElement || input;
    }
    combos.sort((a, b) => a.getBoundingClientRect().top - b.getBoundingClientRect().top);
    if (combos[0]) return combos[0];
    const rDlg = raiz.getBoundingClientRect();
    const noTopo = MESES_TELA.flatMap((m) => folhasComTexto(m, raiz)).filter((el) => {
      const r = el.getBoundingClientRect();
      return r.top < rDlg.top + 200 && r.width >= 40;
    });
    noTopo.sort((a, b) => a.getBoundingClientRect().top - b.getBoundingClientRect().top);
    const folha = noTopo[0];
    return folha && (folha.closest("[role=combobox], .p-dropdown, .ng-select, ng-select, p-dropdown") || folha.parentElement);
  }

  function textoDoComboMes() {
    const w = widgetMes();
    if (!w) return "";
    const rotulo = w.querySelector(".p-dropdown-label, .ng-value-label, .ng-value, .p-dropdown-label-empty, input");
    const bruto = (rotulo && (rotulo.value || rotulo.textContent)) || w.innerText || "";
    const t = norm(bruto);
    if (!t || /^selecione/.test(t)) return "";
    return MESES_PT.find((m) => t === m || t.startsWith(m) || t.split(/[^a-z]+/).includes(m)) || "";
  }

  function mesDoCalendario() {
    const dlg = dialogRegistroAula();
    const n = norm((dlg && dlg.innerText) || "");
    const meses = "janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro";
    const peloGrid = n.match(new RegExp(`(${meses})\\s+d\\s+s\\s+t`));
    if (peloGrid) return peloGrid[1];
    const peloLabel = n.match(new RegExp(`obrigatorio\\s+(${meses})`));
    return peloLabel ? peloLabel[1] : "";
  }

  function mesOk(nomeMes) {
    return mesDoCalendario() === nomeMes;
  }

  function listaMesesAberta() {
    const paineis = q("[role=listbox], .p-dropdown-panel, .p-dropdown-items, .ng-dropdown-panel, .cdk-overlay-pane, ul").filter(visivel)
      .filter((p) => !p.closest("#siage-fila-painel") && !p.closest(".p-dialog-header"));
    return paineis.find((p) => MESES_PT.filter((m) => norm(p.innerText || "").includes(m)).length >= 2) || null;
  }

  function itemMesNaLista(tela, lista) {
    const raiz = lista || document;
    const alvo = norm(tela);
    const opts = q("li, [role=option], .p-dropdown-item, .ng-option", raiz).filter(visivel)
      .filter((el) => !el.closest("#siage-fila-painel"));
    return opts.find((el) => norm(el.textContent) === alvo) || folhasComTexto(tela, raiz)[0] || null;
  }

  function rolaveis(raiz) {
    return [raiz, ...q("*", raiz)].filter((el) => el && el.scrollHeight > el.clientHeight + 8);
  }

  async function fecharListaMes() {
    if (!listaMesesAberta()) return;
    document.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Escape", keyCode: 27 }));
    await esperar(200);
    if (listaMesesAberta()) document.body.click();
    await esperar(250);
  }

  // Caminho 1: seta → rola a barra até o mês → clica. Não digita.
  async function escolherMesPelaLista(nomeMes, tela) {
    const w = widgetMes();
    if (!w) return false;
    let lista = listaMesesAberta();
    if (!lista) {
      clicarPonto(w, 0.92, 0.5);
      lista = await aguardar(listaMesesAberta, 3000);
    }
    if (!lista) return false;
    let item = itemMesNaLista(tela, lista);
    for (let i = 0; i < 50 && !item; i++) {
      rolaveis(lista).forEach((s) => { try { s.scrollTop = Math.min(s.scrollHeight, s.scrollTop + 56); } catch (e) {} });
      await esperar(80);
      lista = listaMesesAberta() || lista;
      item = itemMesNaLista(tela, lista) || itemMesNaLista(tela, document);
    }
    if (!item) return false;
    try { item.scrollIntoView({ block: "nearest" }); } catch (e) {}
    await esperar(80);
    clicarCentro(item);
    await esperar(700);
    return !!(await aguardar(() => mesDoCalendario() === nomeMes, 3500));
  }

  // Caminho 2: clica o campo e escreve o nome do mês. Não rola a lista.
  async function escolherMesDigitando(nomeMes, tela) {
    const w = widgetMes();
    if (!w) return false;
    clicarPonto(w, 0.25, 0.5);
    await esperar(200);
    const campo = (w.querySelector("input:not([type=hidden]):not([type=checkbox])") && visivel(w.querySelector("input")))
      ? w.querySelector("input:not([type=hidden]):not([type=checkbox])")
      : document.activeElement;
    if (campo && campo.focus) campo.focus();
    digitarNaPagina(tela);
    await esperar(300);
    const marcado = q(".ng-option-marked, .p-highlight, [aria-selected=true], .ng-option, .p-dropdown-item, [role=option]").filter(visivel)
      .find((el) => norm(el.textContent) === norm(tela));
    if (marcado) clicarCentro(marcado);
    else enterNaPagina();
    await esperar(700);
    return !!(await aguardar(() => mesDoCalendario() === nomeMes, 3500));
  }

  async function escolherMesDropdown(_raiz, nomeMes) {
    const tela = MESES_TELA[MESES_PT.indexOf(nomeMes)] || nomeMes;
    await fecharAlertaSiage();
    const jaCombo = textoDoComboMes() === nomeMes;
    if (jaCombo && mesDoCalendario() === nomeMes) return true;
    if (await pedirPagina("escolherMes", { tela }, 14000)) {
      return textoDoComboMes() === nomeMes || mesDoCalendario() === nomeMes;
    }
    if (textoDoComboMes() === nomeMes || mesDoCalendario() === nomeMes) return true;
    if (await escolherMesPelaLista(nomeMes, tela)) return true;
    await fecharListaMes();
    if (textoDoComboMes() === nomeMes || mesDoCalendario() === nomeMes) return true;
    return escolherMesDigitando(nomeMes, tela);
  }

  function acharDiaNoCalendario(dlg, dia) {
    const pad = String(dia).padStart(2, "0");
    const raiz = dlg || document.body;
    const caixas = [];
    q("div, span, button, td, a", raiz).forEach((el) => {
      if (el.closest("#siage-fila-painel")) return;
      if (!visivel(el)) return;
      const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).join("");
      const txt = own || (el.children.length <= 1 ? (el.textContent || "").trim() : "");
      if (txt !== pad && txt !== String(dia)) return;
      const r = el.getBoundingClientRect();
      if (r.width < 16 || r.height < 16 || r.width > 90 || r.height > 90) return;
      caixas.push(el);
    });
    caixas.sort((a, b) => {
      const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
      return (ra.width * ra.height) - (rb.width * rb.height);
    });
    const folha = caixas[0];
    if (!folha) return null;
    let n = folha;
    for (let i = 0; i < 4 && n; i++) {
      const r = n.getBoundingClientRect();
      if (r.width >= 28 && r.width <= 90 && r.height >= 28 && r.height <= 90) return n;
      n = n.parentElement;
    }
    return folha;
  }

  function formAulaAberto() {
    return !!(botaoComTexto(/^salvar/) || campo(/^tempo/) || campo(/horario/) || (!ehModalMesData() && naTelaDeCadastro()));
  }

  function modalCalendarioPronto() {
    if (!ehModalMesData()) return false;
    const dlg = dialogRegistroAula();
    if (!dlg) return false;
    const t = norm(dlg.innerText || "");
    return /d\s+s\s+t\s+q/.test(t) && !!(widgetMes() || /obrigatorio/.test(t));
  }

  async function sairDoCampoMes() {
    await fecharListaMes();
    try { document.activeElement && document.activeElement.blur(); } catch (e) {}
    const dlg = dialogRegistroAula();
    if (!dlg) return;
    const combo = widgetMes();
    const cab = dlg.querySelector(".p-dialog-header, .modal-header, [role=heading]") || dlg;
    const r = cab.getBoundingClientRect();
    clicarNaPagina(r.left + Math.min(r.width / 2, 280), r.top + 16);
    const titulo = MESES_TELA.flatMap((m) => folhasComTexto(m, dlg)).find((el) => combo && !combo.contains(el));
    if (titulo) clicarNativo(titulo);
    await esperar(400);
  }

  async function escolherDataModal(aula) {
    const [, mes, dia] = aula.data.split("-").map(Number);
    const nomeMes = MESES_PT[mes - 1];
    const tela = MESES_TELA[mes - 1] || nomeMes;
    const pad = String(dia).padStart(2, "0");

    await aguardar(modalCalendarioPronto, 10000);
    await esperar(1200);

    for (let tentativa = 1; tentativa <= 3; tentativa++) {
      await fecharAlertaSiage();
      if (formAulaAberto()) return { ok: true, dataOk: true };
      if (!ehModalMesData()) break;
      await fecharListaMes();
      await esperar(400);

      await escolherMesDropdown(null, nomeMes);
      const quadroNoMes = await aguardar(() => mesDoCalendario() === nomeMes, 8000);
      if (!quadroNoMes) {
        if (tentativa === 3) return { ok: false, aviso: `O calendário não mudou para ${tela}.` };
        continue;
      }
      await esperar(800);
      await sairDoCampoMes();
      await aguardar(() => {
        const t = norm((dialogRegistroAula() || document.body).innerText || "");
        return !/mes e obrigatorio/.test(t);
      }, 4000);
      await esperar(800);

      const dlg = dialogRegistroAula() || document.body;
      if (mesDoCalendario() !== nomeMes) continue;
      const celula = acharDiaNoCalendario(dlg, dia);
      if (!celula) {
        if (tentativa === 3) return { ok: false, aviso: `Não achei a caixa do dia ${pad} em ${tela}.` };
        continue;
      }
      const ja = ehAzul(fundo(celula)) || ehAzul(corVisual(celula)) || ehAzul(fundo(celula.parentElement));
      clicarCentro(celula);
      await esperar(1000);
      if (formAulaAberto()) return { ok: true, dataOk: true };
      if (ja && ehModalMesData() && mesDoCalendario() === nomeMes) {
        return { ok: true, ja: true, dataOk: true };
      }
      const depois = norm((dialogRegistroAula() || document.body).innerText || "").slice(0, 2500);
      if (/mes e obrigatorio/.test(depois) && tentativa < 3) continue;
    }
    if (formAulaAberto()) return { ok: true, dataOk: true };
    return { ok: false, aviso: `Cliquei o dia ${pad} em ${tela}, mas o formulário não abriu.` };
  }

  async function garantirTelaFrequencia() {
    if (naFormularioFrequencia()) return "form";
    if (!naAbaFrequencia() && !botaoRegistrarFrequencia()) {
      clicarNav(/^frequencia$/);
      await aguardar(() => naAbaFrequencia() || botaoRegistrarFrequencia() || naFormularioFrequencia(), 10000);
    }
    const btn = botaoRegistrarFrequencia();
    if (btn && !naFormularioFrequencia()) {
      clicarNativo(btn);
      await aguardar(() => naFormularioFrequencia() || campo(/^data/) || campo(/^periodo/), 12000);
      await esperar(400);
    }
    return naFormularioFrequencia() ? "form" : (botaoRegistrarFrequencia() || naAbaFrequencia() ? "lista" : "outra");
  }

  function campoForm(re) {
    const lab = q("label, .p-float-label, span, p, legend").filter(visivel).find((l) => {
      if (l.closest("#siage-fila-painel")) return false;
      const t = norm(l.textContent);
      return t.length < 22 && re.test(t) && !/obrigatorio/.test(t);
    });
    if (!lab) return null;
    return lab.closest(".form-group, app-field, .p-field, .field, .p-formgroup, mat-form-field, p-dropdown, p-calendar, ng-select") || lab.parentElement;
  }

  function clicarPaginaEl(el) {
    if (!el) return false;
    const r = el.getBoundingClientRect();
    clicarNaPagina(r.left + Math.max(4, r.width / 2), r.top + Math.max(4, r.height / 2));
    clicarNativo(el);
    return true;
  }

  function setaDoCampo(bloco) {
    if (!bloco) return null;
    const porClasse = q(".p-dropdown-trigger, .p-select-dropdown, .ui-dropdown-trigger, .ng-arrow-wrapper, .p-autocomplete-dropdown, [class*=chevron], [class*=arrow]", bloco).find(visivel);
    if (porClasse) return porClasse;
    const r = bloco.getBoundingClientRect();
    return q("button, span, i, svg, a", bloco).filter(visivel).find((el) => {
      const b = el.getBoundingClientRect();
      return b.left > r.left + r.width * 0.62 && b.width <= 52 && b.height <= 52;
    });
  }

  async function escolherNaListaSuspensa(rotuloRe, casaFn, trecho, rotulo) {
    recusarCancelarPreenchimento();
    if (rotulo && trecho) {
      const viaPagina = await pedirPagina("listaFreq", { rotulo, trecho }, 8000);
      if (viaPagina) return true;
    }
    const bloco = campoForm(rotuloRe) || campo(rotuloRe);
    if (!bloco) return false;
    const ja = () => {
      const t = norm(bloco.innerText || bloco.value || "");
      const linha = (t.split("\n")[0] || t);
      return casaFn(linha) && !/selecione|obrigatorio/.test(linha);
    };
    if (ja()) return true;
    const seta = setaDoCampo(bloco) || bloco.querySelector("[role=combobox], .p-dropdown, .p-select") || bloco;
    clicarPaginaEl(seta);
    const itemSel = "li.p-dropdown-item, li.p-select-option, li.ui-dropdown-item, li.p-autocomplete-item, li.p-multiselect-item, .ng-option, [role=option]";
    const item = await aguardar(() => q(itemSel).filter(visivel).find((li) => {
      const t = norm(li.textContent);
      return casaFn(t) && t.length < 80 && !li.closest("#siage-fila-painel");
    }), 5000);
    if (!item) return false;
    clicarPaginaEl(item);
    await esperar(450);
    return true;
  }

  function painelCalendarioFreq() {
    const porClasse = q(".p-datepicker, .ui-datepicker, .owl-dt-container, .mat-datepicker-popup, .cdk-overlay-pane, [class*=datepicker]")
      .filter(visivel)
      .find((el) => {
        if (el.closest("#siage-fila-painel")) return false;
        const t = norm(el.innerText || "");
        return (/hoje/.test(t) && /limpar/.test(t)) || (/d\s+s\s+t\s+q/.test(t) && MESES_PT.some((m) => t.includes(m)));
      });
    if (porClasse) return porClasse;
    return q("div").filter(visivel).find((el) => {
      if (el.closest("#siage-fila-painel")) return false;
      const t = norm(el.innerText || "");
      if (t.length < 50 || t.length > 900) return false;
      return /hoje/.test(t) && /limpar/.test(t) && /d\s+s\s+t\s+q/.test(t);
    });
  }

  function mesAnoDoPainel(painel) {
    const t = norm((painel && painel.innerText) || "").slice(0, 500);
    const mi = MESES_PT.findIndex((m) => t.includes(m));
    const ano = parseInt((t.match(/20\d{2}/) || [])[0], 10);
    return { m: mi + 1, a: ano || 0 };
  }

  function tituloMesAno(painel) {
    return q("button, span, div, select, a, [role=button]", painel).filter(visivel).find((el) => {
      const t = norm(el.textContent || "");
      return t.length < 32 && MESES_PT.some((m) => t.includes(m)) && /20\d{2}/.test(t);
    });
  }

  function setasDoTopo(painel) {
    const box = painel.getBoundingClientRect();
    const titulo = tituloMesAno(painel);
    const tr = titulo ? titulo.getBoundingClientRect() : { left: box.left + box.width / 2, right: box.left + box.width / 2 };
    const topo = q("button, a, span, i, svg", painel).filter(visivel).filter((el) => {
      if (titulo && (el === titulo || titulo.contains(el))) return false;
      const r = el.getBoundingClientRect();
      return r.top < box.top + 52 && r.height <= 44 && r.width <= 44;
    });
    const esq = topo
      .filter((el) => el.getBoundingClientRect().right <= tr.left + 6)
      .sort((a, b) => b.getBoundingClientRect().left - a.getBoundingClientRect().left)[0]
      || q(".p-datepicker-prev, .ui-datepicker-prev, [class*=prev]", painel).find(visivel);
    const dir = topo
      .filter((el) => el.getBoundingClientRect().left >= tr.right - 6)
      .sort((a, b) => a.getBoundingClientRect().left - b.getBoundingClientRect().left)[0]
      || q(".p-datepicker-next, .ui-datepicker-next, [class*=next]", painel).find(visivel);
    return { esq, dir };
  }

  async function escolherMesPelasSetas(painel, mes, ano) {
    for (let i = 0; i < 24; i++) {
      painel = painelCalendarioFreq() || painel;
      const atual = mesAnoDoPainel(painel);
      if (atual.m === mes && atual.a === ano) return true;
      if (!atual.m) return false;
      const diff = (ano - atual.a) * 12 + (mes - atual.m);
      const setas = setasDoTopo(painel);
      const seta = diff > 0 ? setas.dir : setas.esq;
      if (!seta) return false;
      clicarPaginaEl(seta);
      const mudou = await aguardar(() => {
        const n = mesAnoDoPainel(painelCalendarioFreq() || painel);
        return n.m !== atual.m || n.a !== atual.a;
      }, 2000);
      if (!mudou) await esperar(350);
    }
    const fim = mesAnoDoPainel(painelCalendarioFreq() || painel);
    return fim.m === mes && fim.a === ano;
  }

  function clicarDiaFreq(painel, dia) {
    const pad = String(Number(dia));
    const nos = q("td, button, span, div", painel).filter(visivel).filter((el) => {
      if (el.closest("#siage-fila-painel")) return false;
      if (/other-month|p-disabled|ui-state-disabled|outside|muted/.test(el.className)) return false;
      const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).join("");
      const t = (own || (el.textContent || "")).trim();
      if (t !== pad && t !== String(dia)) return false;
      const r = el.getBoundingClientRect();
      return r.width >= 14 && r.width <= 64 && r.height >= 14 && r.height <= 64;
    });
    const vivos = nos.filter((el) => {
      const op = parseFloat(getComputedStyle(el).opacity || "1");
      const rgb = rgbDe(getComputedStyle(el).color);
      const cinza = rgb && Math.abs(rgb[0] - rgb[1]) < 12 && Math.abs(rgb[1] - rgb[2]) < 12 && rgb[0] > 140;
      return op > 0.65 && !cinza;
    });
    const alvo = (vivos.length ? vivos : nos)[0];
    if (!alvo) return false;
    clicarPaginaEl(alvo);
    return true;
  }

  function iconeCalendario() {
    const bloco = campoForm(/^data/) || campo(/^data/);
    if (!bloco) return null;
    const porClasse = q("button, .p-datepicker-trigger, .ui-datepicker-trigger, [class*=calendar], [class*=pi-calendar]", bloco)
      .filter(visivel)
      .find((el) => {
        const r = el.getBoundingClientRect();
        return r.width <= 56 && r.height <= 56;
      });
    if (porClasse) return porClasse;
    const input = bloco.querySelector("input");
    if (!input) return null;
    const ir = input.getBoundingClientRect();
    return q("button, span, i, svg, a", bloco.parentElement || bloco).filter(visivel).find((el) => {
      const r = el.getBoundingClientRect();
      return r.left >= ir.right - 10 && r.width <= 56 && Math.abs(r.top - ir.top) < 24;
    });
  }

  async function escolherDataFrequencia(aula, resultado) {
    recusarCancelarPreenchimento();
    const dataBr = aula.data_br || (aula.data && String(aula.data).includes("-") ? String(aula.data).split("-").reverse().join("/") : aula.data);
    const r = await pedirPaginaDetalhe("dataFreq", { iso: aula.data, data_br: dataBr }, 25000);
    resultado.dataOk = !!(r && r.ok);
    if (!resultado.dataOk) {
      resultado.aviso = (r && r.aviso) || "Não consegui escrever a data no campo.";
    }
    return resultado.dataOk;
  }

  function numeroDoRotuloTempo(texto) {
    const t = norm(texto).replace(/[º°ª]/g, "o");
    const m = t.match(/(?:^|[^0-9])(\d{1,2})\s*o?\s*tempo\b/);
    return m ? Number(m[1]) : 0;
  }

  function painelListaTempo() {
    return q(".p-multiselect-panel, .p-dropdown-panel, .ui-multiselect-panel, .ui-dropdown-panel, .p-overlaypanel, .p-select-overlay, [role=listbox], .cdk-overlay-pane")
      .filter(visivel)
      .find((p) => {
        if (p.closest("#siage-fila-painel")) return false;
        const t = norm(p.innerText || "").replace(/[º°ª]/g, "o");
        return /\d{1,2}\s*o?\s*tempo/.test(t) && t.split("tempo").length >= 2;
      });
  }

  function listarOpcoesTempo() {
    const raiz = painelListaTempo() || document;
    const nos = q("[role=option], li, .p-multiselect-item, .p-multiselect-option, .p-dropdown-item, .p-select-option, label", raiz)
      .filter(visivel)
      .filter((el) => {
        if (el.closest("#siage-fila-painel")) return false;
        const n = numeroDoRotuloTempo(el.textContent);
        const t = (el.textContent || "").trim();
        return n > 0 && t.length < 48;
      });
    const mapa = new Map();
    nos.forEach((el) => {
      const n = numeroDoRotuloTempo(el.textContent);
      const atual = mapa.get(n);
      if (!atual || atual.contains(el) || el.textContent.trim().length < atual.textContent.trim().length) mapa.set(n, el);
    });
    return [...mapa.entries()].map(([n, el]) => ({
      n,
      el,
      disabled: /p-disabled|ui-state-disabled/.test(el.className || "") || el.getAttribute("aria-disabled") === "true"
    }));
  }

  async function abrirListaTempo(bloco, seletor) {
    if (listarOpcoesTempo().length) return true;
    const gatilho = (seletor && (seletor.querySelector(".p-dropdown-trigger, .p-multiselect-trigger, .p-multiselect-dropdown, .ui-dropdown-trigger, .p-select-dropdown") || seletor))
      || setaDoCampo(bloco)
      || bloco;
    clicarPaginaEl(gatilho);
    return !!(await aguardar(() => listarOpcoesTempo().length, 4500));
  }

  async function clicarOpcaoTempo(el) {
    const alvo = el.querySelector(".p-checkbox-box, .p-checkbox, input[type=checkbox]") || el;
    clicarPaginaEl(alvo);
    await esperar(280);
  }

  async function escolherTemposComFallback(aula, resultado) {
    const pedidos = (aula.tempos || []).map((t) => parseInt(String(t).match(/\d+/) || t, 10)).filter((n) => n > 0);
    resultado.temposFalha = [];
    resultado.temposOk = [];
    if (!pedidos.length) {
      resultado.aviso = "O Maestro não enviou o número do tempo desta aula.";
      return resultado;
    }
    const detalhe = await pedirPaginaDetalhe("marcarTempos", { ns: pedidos, substituto: true }, 45000);
    if (detalhe && detalhe.ok) {
      const escolhidos = (Array.isArray(detalhe.escolhidos) && detalhe.escolhidos.length)
        ? detalhe.escolhidos.map(Number)
        : pedidos;
      resultado.temposOk = escolhidos;
      resultado.temposFalha = pedidos.filter((t) => !escolhidos.includes(Number(t)));
      if (detalhe.substituto) {
        resultado.aviso = `Gravei o(s) tempo(s) ${escolhidos.join(", ")} (o SIAGE não tinha todos os pedidos).`;
      }
    } else {
      resultado.temposFalha = [...pedidos];
      resultado.aviso = (detalhe && detalhe.aviso) || `Não consegui marcar o tempo ${pedidos.join(", ")}.`;
      resultado.motivo = detalhe && detalhe.motivo;
    }
    return resultado;
  }

  function painelTemposNaPagina() {
    return q("div, ul").filter(visivel).some((p) => {
      if (p.closest("#siage-fila-painel")) return false;
      const t = norm(p.innerText || "").replace(/[º°ª]/g, "o");
      return /1\s*o?\s*tempo/.test(t) && /2\s*o?\s*tempo/.test(t);
    });
  }

  // ---------- Registrar uma aula (aba Frequência; preenchimento no estilo 4.1.4) ----------
  async function registrarAula(aula, salvar) {
    const [ano, mes, dia] = aula.data.split("-").map(Number);
    const resultado = { dataOk: false, temposOk: [], temposFalha: [...aula.tempos], salvou: false, aviso: "" };
    recusarCancelarPreenchimento();

    function valorDataTela() {
      const input = q("input").find((el) => visivel(el) && /dd.?mm.?aa/.test(norm(el.getAttribute("placeholder") || el.placeholder || "")));
      return ((input && input.value) || "").replace(/\s/g, "");
    }
    function dataNaTela(a) {
      const br = a.data_br || dataBR(a.data);
      const v = valorDataTela();
      return v.includes(br) || v.includes(br.slice(0, 6) + br.slice(-2));
    }
    function periodoNaTela(a) {
      if (!a.periodo) return true;
      const bloco = campo(/^periodo$/) || campoForm(/^periodo/);
      const input = bloco && bloco.querySelector("input");
      const t = norm(((input && input.value) || (bloco && bloco.innerText) || ""));
      return new RegExp(`(^|[^0-9])${a.periodo}\\s*(º|°|o)?\\s*periodo`).test(t);
    }

    if (!naLista() && !naTelaDeCadastro()) {
      await garantirTelaFrequencia();
      await aguardar(() => naLista() || naTelaDeCadastro() || naFormularioFrequencia(), 8000);
    }
    await abrirCadastroLimpo(aula);

    if (!botaoComTexto(/^salvar/)) {
      const registrar = botaoComTexto(/registrar frequencia/) || botaoNovoRegistro();
      if (registrar) {
        registrar.click();
        await aguardar(() => botaoComTexto(/^salvar/) || campo(/^data$/), 10000);
        await esperar(500);
      }
    }
    if (ehModalMesData()) {
      const rModal = await escolherDataModal(aula);
      if (rModal.ja) {
        resultado.dataOk = true;
        resultado.salvou = true;
        resultado.ja = true;
        resultado.aviso = "já consta na Frequência";
        return resultado;
      }
      if (!rModal.ok) {
        resultado.aviso = rModal.aviso || "Não consegui escolher a data no calendário.";
        return resultado;
      }
      resultado.dataOk = true;
    }
    if (!botaoComTexto(/^salvar/) && !campo(/^tempo$/) && !campo(/^data$/)) {
      resultado.aviso = "Abra a tela de Registrar Frequência da turma.";
      return resultado;
    }

    const MESES_EN = ["january","february","march","april","may","june","july","august","september","october","november","december"];
    if (dataConfereAula(aula) || dataNaTela(aula)) resultado.dataOk = true;
    const blocoData = campo(/^data$/) || campoForm(/^data/);
    const inputData = blocoData && blocoData.querySelector("p-calendar input, input");
    if (inputData && !resultado.dataOk) {
      recusarCancelarPreenchimento();
      const painelAberto = () => q(".ui-datepicker, .p-datepicker").find(visivel) || painelCalendarioFreq();
      clicarPaginaEl(inputData);
      let painel = await aguardar(painelAberto, 2000);
      if (!painel) {
        const gatilho = blocoData.querySelector(".ui-datepicker-trigger, .p-datepicker-trigger, button") || iconeCalendario();
        if (gatilho) clicarPaginaEl(gatilho);
        painel = await aguardar(painelAberto, 3000);
      }
      if (painel) {
        const lerMesAno = () => {
          painel = painelAberto() || painel;
          const eMes = painel.querySelector(".ui-datepicker-month, .p-datepicker-month");
          const eAno = painel.querySelector(".ui-datepicker-year, .p-datepicker-year");
          if (eMes && eAno) {
            let m;
            if (eMes.tagName === "SELECT") m = eMes.selectedIndex + 1;
            else {
              const t = norm(eMes.textContent);
              m = Math.max(MESES_PT.indexOf(t), MESES_EN.indexOf(t), t ? MESES_PT.findIndex((x) => x.startsWith(t.slice(0, 3))) : -1) + 1;
            }
            const a = eAno.tagName === "SELECT" ? parseInt(eAno.value, 10) : parseInt(eAno.textContent, 10);
            if (m && a > 1900 && a < 2100) return { m, a, eMes, eAno };
          }
          const fb = mesAnoDoPainel(painel);
          return fb.m ? { m: fb.m, a: fb.a } : null;
        };
        const escolherNaLista = (sel, valor) => {
          const op = [...sel.options].find((o) => o.value === String(valor) || norm(o.textContent) === String(valor));
          if (!op) return false;
          sel.value = op.value;
          sel.dispatchEvent(new Event("change", { bubbles: true }));
          return true;
        };
        let anterior = "";
        let repetidas = 0;
        for (let i = 0; i < 40; i++) {
          const atual = lerMesAno();
          if (!atual) break;
          if (atual.eAno && atual.a !== ano && atual.eAno.tagName === "SELECT" && escolherNaLista(atual.eAno, ano)) { await esperar(200); continue; }
          if (atual.eMes && atual.m !== mes && atual.eMes.tagName === "SELECT" && escolherNaLista(atual.eMes, mes - 1)) { await esperar(200); continue; }
          const diff = (ano - atual.a) * 12 + (mes - atual.m);
          if (diff === 0) break;
          const chave = atual.m + "/" + atual.a;
          repetidas = chave === anterior ? repetidas + 1 : 0;
          anterior = chave;
          if (repetidas >= 3) {
            await escolherMesPelasSetas(painel, mes, ano);
            break;
          }
          const nav = painel.querySelector(diff > 0 ? ".ui-datepicker-next, .p-datepicker-next" : ".ui-datepicker-prev, .p-datepicker-prev");
          if (nav) clicarPaginaEl(nav);
          else if (!(await escolherMesPelasSetas(painel, mes, ano))) break;
          await esperar(200);
        }
        const conferido = lerMesAno();
        if (!conferido || conferido.m !== mes || conferido.a !== ano) {
          resultado.aviso = "Não consegui chegar ao mês certo no calendário.";
          recusarCancelarPreenchimento();
          return resultado;
        }
        painel = painelAberto() || painel;
        const celula = q("td", painel).find((td) =>
          !/other-month|ui-datepicker-other|p-datepicker-other/.test(td.className) && norm(td.textContent) === String(dia));
        const alvo = celula && celula.querySelector("a, span");
        const bloqueado = alvo && /ui-state-disabled|p-disabled/.test(alvo.className + " " + (celula && celula.className || ""));
        if (alvo && !bloqueado) clicarPaginaEl(alvo);
        else if (!clicarDiaFreq(painel, dia)) {
          resultado.aviso = "O dia escolhido está bloqueado no calendário do SIAGE.";
          recusarCancelarPreenchimento();
          return resultado;
        }
        await esperar(800);
        recusarCancelarPreenchimento();
        resultado.dataOk = dataNaTela(aula) || dataConfereAula(aula);
        if (!resultado.dataOk) resultado.aviso = `Maestro pediu ${aula.data_br || dataBR(aula.data)} e o campo ficou "${inputData.value || valorDataTela()}".`;
      }
    }
    if (!resultado.dataOk) await escolherDataFrequencia(aula, resultado);
    resultado.dataOk = dataNaTela(aula) || dataConfereAula(aula);
    if (!resultado.dataOk) {
      if (!resultado.aviso) resultado.aviso = `Maestro pediu ${aula.data_br || dataBR(aula.data)} e o campo ficou "${valorDataTela()}".`;
      return resultado;
    }
    await esperar(600);

    if (aula.periodo) {
      const blocoPer = campo(/^periodo$/) || campoForm(/^periodo/);
      if (blocoPer) {
        const inputPer = blocoPer.querySelector("input");
        const itemPer = "li.ui-autocomplete-list-item, li.p-autocomplete-item, li.ui-dropdown-item, li.p-dropdown-item, li.p-select-option, [role=option]";
        const casaPer = (li) => new RegExp(`(^|[^0-9])${aula.periodo}\\s*(º|°|o)?\\s*periodo`).test(norm(li.textContent));
        const jaTem = () => periodoNaTela(aula) || (inputPer && new RegExp(`^${aula.periodo}\\D`).test(norm(inputPer.value)));
        if (!jaTem()) {
          const dd = blocoPer.querySelector(".ui-autocomplete-dropdown, .p-autocomplete-dropdown, .p-dropdown-trigger, .p-dropdown, .ui-dropdown-trigger");
          if (dd) clicarPaginaEl(dd);
          else if (inputPer) clicarPaginaEl(inputPer);
          else clicarPaginaEl(setaDoCampo(blocoPer) || blocoPer);
          let item = await aguardar(() => q(itemPer).filter(visivel).find(casaPer), 3000);
          if (!item && inputPer) {
            inputPer.focus();
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(inputPer, String(aula.periodo));
            inputPer.dispatchEvent(new Event("input", { bubbles: true }));
            inputPer.dispatchEvent(new KeyboardEvent("keyup", { bubbles: true, key: String(aula.periodo) }));
            item = await aguardar(() => q(itemPer).filter(visivel).find(casaPer), 4000);
          }
          if (item) { clicarPaginaEl(item); await esperar(400); }
        }
        if (!jaTem()) {
          const okPer = await escolherNaListaSuspensa(/^periodo/, (texto) => new RegExp(`(^|[^0-9])${aula.periodo}\\s*(º|°|o)?\\s*periodo`).test(norm(texto)), aula.periodo_label || `${aula.periodo}º Período`, "periodo");
          if (!okPer) {
            resultado.aviso = `Não consegui escolher o ${aula.periodo}º Período.`;
            return resultado;
          }
        }
        await esperar(400);
      }
    }

    if (!dataNaTela(aula) && !dataConfereAula(aula)) {
      resultado.dataOk = false;
      await escolherDataFrequencia(aula, resultado);
      resultado.dataOk = dataNaTela(aula) || dataConfereAula(aula);
      if (!resultado.dataOk) {
        resultado.aviso = resultado.aviso || `Maestro pediu ${aula.data_br || dataBR(aula.data)} e o campo ficou "${valorDataTela()}".`;
        return resultado;
      }
    }
    const blocoTempo = await aguardar(() => campo(/^tempo$/) || campoForm(/^tempo/), 4000);
    if (blocoTempo) {
      await aguardar(() => {
        const caixa = blocoTempo.querySelector("[role=combobox], .p-multiselect, .p-dropdown, .p-select");
        return !caixa || !/p-disabled|disabled/.test(caixa.className || "");
      }, 6000);
      await esperar(400);
    }

    await escolherTemposComFallback(aula, resultado);

    if (!resultado.temposOk.length) {
      const vagos = listarOpcoesTempo().filter((o) => !o.disabled);
      if (dataNaTela(aula) && periodoNaTela(aula) && listarOpcoesTempo().length && !vagos.length) {
        resultado.ja = true;
        resultado.aviso = "já consta na Frequência (não há tempo vago nesta data)";
        return resultado;
      }
      if (!resultado.aviso) {
        resultado.aviso = resultado.temposFalha.length
          ? `Não consegui escolher o tempo ${resultado.temposFalha.join(", ")}.`
          : "Não encontrei o campo Tempo.";
      }
      return resultado;
    }

    if (resultado.temposOk.length) {
      await aguardar(() => listarAlunos().length > 0, 8000);
      await marcarAlunos(aula);
    }

    if (salvar && resultado.temposOk.length) {
      const gravar = await aguardar(() => {
        const b = botaoComTexto(/^salvar/) || botaoComTexto(/^registrar$/) || botaoComTexto(/gravar frequencia/);
        return b && !b.disabled ? b : null;
      }, 8000);
      if (gravar) { gravar.click(); resultado.salvou = true; }
      else resultado.aviso = "O botão Salvar está desativado; confira os campos.";
    }
    return resultado;
  }

  function listarAlunos() {
    const controles = q(".p-inputswitch, .p-toggleswitch, [role='switch'], input[type='checkbox']");
    const visto = new Set();
    const itens = [];
    controles.forEach((ctrl) => {
      if (ctrl.closest("thead, .p-datatable-thead, header, nav, #siage-fila-painel")) return;
      const linha = ctrl.closest("tr") || ctrl.closest("[class*='p-datatable-row']") || ctrl.closest("[class*='row']");
      if (!linha || visto.has(linha)) return;
      const celulas = q("td", linha);
      const nomeCel = celulas.find((td) => !td.contains(ctrl));
      const nome = ((nomeCel || celulas[0] || linha).innerText || "").trim().split("\n")[0].trim();
      if (!nome || norm(nome) === "nome") return;
      visto.add(linha);
      itens.push({
        linha,
        controle: ctrl.closest(".p-inputswitch, .p-toggleswitch") || ctrl,
        nome
      });
    });
    return itens;
  }

  function pontuacaoNome(siageNome, maestroNome) {
    const a = norm(siageNome);
    const b = norm(maestroNome);
    if (!a || !b) return 0;
    if (a === b) return 100;
    if (a.startsWith(b) || b.startsWith(a)) return 50;
    const ta = a.split(" ").filter((t) => t.length > 1);
    const tb = b.split(" ").filter((t) => t.length > 1);
    return tb.filter((t) => ta.includes(t)).length;
  }

  function acharAluno(itens, nome) {
    let melhor = null;
    let melhorN = 0;
    itens.forEach((item) => {
      const n = pontuacaoNome(item.nome, nome);
      if (n > melhorN) { melhor = item; melhorN = n; }
    });
    return melhorN >= 2 ? melhor : null;
  }

  function rgbDe(cor) {
    const m = String(cor).match(/\d+/g);
    if (!m || m.length < 3) return null;
    return m.slice(0, 3).map(Number);
  }
  function ehAzul(cor) {
    const v = rgbDe(cor);
    if (!v) return false;
    const [r, g, b] = v;
    return b > 110 && b > r + 25 && b >= g;
  }
  function ehVerde(cor) {
    const v = rgbDe(cor);
    if (!v) return false;
    const [r, g, b] = v;
    return g > 110 && g > r && g > b;
  }
  function ehLaranja(cor) {
    const v = rgbDe(cor);
    if (!v) return false;
    const [r, g, b] = v;
    return r > 160 && g > 80 && g < 180 && b < 90;
  }
  function ehVermelho(cor) {
    const v = rgbDe(cor);
    if (!v) return false;
    const [r, g, b] = v;
    return r > 140 && r > g + 30 && r > b + 30;
  }
  function fundo(el) {
    try { return window.getComputedStyle(el).backgroundColor; } catch (e) { return ""; }
  }
  function corVisual(el) {
    if (!el || el.nodeType !== 1) return "";
    const nos = [el, el.parentElement];
    try { nos.push(...el.querySelectorAll("span, div, button")); } catch (e) {}
    const cores = nos.filter(Boolean).map(fundo);
    return cores.find((c) => ehVerde(c) || ehAzul(c) || ehLaranja(c) || ehVermelho(c)) || fundo(el);
  }
  function estadoPresenca(raiz) {
    const checkbox = raiz.querySelector("input[type='checkbox']");
    const visual = raiz.querySelector("[role='switch'], .p-inputswitch, .p-inputswitch-slider, .p-toggleswitch") ||
      checkbox?.closest("label, div, span, td") || checkbox;
    const ligado = checkbox
      ? checkbox.checked
      : visual?.getAttribute("aria-checked") === "true" || /checked|active|on/i.test(visual?.className || "");
    const cor = corVisual(visual);
    if (ehAzul(cor) || /justif|info|azul|blue/i.test(`${visual?.className || ""} ${raiz.className || ""}`)) return "justified";
    if (ehLaranja(cor)) return "present";
    if ((!ligado && !ehVerde(cor)) || ehVermelho(cor)) return "absent";
    return "present";
  }
  function switchLigado(linha, controle) {
    const sw = linha.querySelector(".p-inputswitch, .p-toggleswitch") || controle;
    if (sw?.classList?.contains("p-inputswitch-checked")) return true;
    if (sw?.classList?.contains("p-toggleswitch-checked")) return true;
    if (sw?.getAttribute("aria-checked") === "true") return true;
    const checkbox = linha.querySelector("input[type='checkbox']");
    return Boolean(checkbox?.checked);
  }
  function aplicarToggle(linha, controle, desejado) {
    const alvo = linha.querySelector(".p-inputswitch-slider, .p-toggleswitch-slider") || controle;
    if (!alvo) return;
    for (let i = 0; i < 5; i++) {
      if (estadoPresenca(linha) === desejado) return;
      alvo.click();
    }
  }

  async function marcarAlunos(aula) {
    const faltas = aula.faltas || [];
    const justificados = aula.justificados || [];
    const atrasados = aula.atrasados || aula.late || [];
    const lista = await aguardar(() => {
      const itens = listarAlunos();
      return itens.length > 1 ? itens : null;
    }, 8000) || listarAlunos();
    if (!lista.length) return { ok: faltas.length + justificados.length === 0, marcados: 0 };
    let marcados = 0;
    atrasados.forEach((nome) => {
      const item = acharAluno(lista, nome);
      if (!item) return;
      aplicarToggle(item.linha, item.controle, "present");
      marcados += 1;
    });
    faltas.forEach((nome) => {
      const item = acharAluno(lista, nome);
      if (!item) return;
      aplicarToggle(item.linha, item.controle, "absent");
      marcados += 1;
    });
    justificados.forEach((nome) => {
      const item = acharAluno(lista, nome);
      if (!item) return;
      aplicarToggle(item.linha, item.controle, "justified");
      marcados += 1;
    });
    await esperar(250);
    return { ok: true, marcados };
  }


  function valorDataFrequencia() {
    const input = q("input").find((el) => visivel(el) && /dd.?mm.?aa/.test(norm(el.getAttribute("placeholder") || el.placeholder || "")));
    return ((input && input.value) || "").replace(/\s/g, "");
  }

  function dataConfereAula(aula) {
    const br = aula.data_br || dataBR(aula.data);
    const v = valorDataFrequencia();
    return !!(v && (v.includes(br) || v.includes(br.slice(0, 6) + br.slice(-2))));
  }

  function aceitarDescarteFormulario() {
    const t = norm(document.body.innerText || "");
    if (!/cancelar o preenchimento|descartar|perder os dados/.test(t)) return false;
    const sim = botoes().find((b) => /^(sim|ok|confirmar)$/.test(norm(b.textContent))) || q(".swal2-confirm").find(visivel);
    if (sim) { sim.click(); return true; }
    return false;
  }

  async function abrirCadastroLimpo(aula) {
    if (naTelaDeCadastro() || naFormularioFrequencia() || campo(/^data$/)) {
      if (valorDataFrequencia() && !dataConfereAula(aula)) {
        const cancelar = botaoComTexto(/^(cancelar|voltar)/);
        if (cancelar) {
          cancelar.click();
          await esperar(500);
          aceitarDescarteFormulario();
          await aguardar(() => naLista() || botaoRegistrarFrequencia() || botaoComTexto(/registrar frequencia/), 8000);
          await esperar(400);
        }
      }
    }
    if (!botaoComTexto(/^salvar/) || (!dataConfereAula(aula) && valorDataFrequencia())) {
      const registrar = botaoComTexto(/registrar frequencia/) || botaoNovoRegistro();
      if (registrar && !botaoComTexto(/^salvar/)) {
        registrar.click();
        await aguardar(() => botaoComTexto(/^salvar/) || campo(/^data$/), 10000);
        await esperar(500);
      }
    }
  }

  async function voltarParaLista() {
    if (naLista()) return true;
    const cancelar = botaoComTexto(/^(cancelar|voltar)/);
    if (cancelar) cancelar.click(); else history.back();
    await esperar(800);
    aceitarDescarteFormulario();
    const confirmar = q(".swal2-confirm, .modal.show .btn-primary, .ui-dialog .ui-button, .p-dialog .p-button").find(visivel);
    if (confirmar && !naLista()) confirmar.click();
    return !!(await aguardar(naLista, 10000));
  }

  // Janelas de aviso do SIAGE (swal/toast). Não inclui textos fixos da página.
  function avisoNaTela() {
    return q(".swal2-popup .swal2-title, .swal2-popup .swal2-html-container, .toast-message, .toast-body, .ui-toast-detail, .ui-toast-summary, .p-toast-detail")
      .filter(visivel).map((e) => e.textContent.trim()).filter(Boolean).join(" ").slice(0, 160);
  }
  function tipoDoAviso(texto) {
    const t = norm(texto);
    if (/ja exist|ja registr|ja possui|ja foi|duplic/.test(t)) return "repetida";
    if ((/senha/.test(t) && /incorret|invalid|errad|nao confere|nao corresponde/.test(t)) || /credenc/.test(t)) return "senha";
    if (/sucesso|salv[oa] com|registrad[oa] com|realizad[oa] com/.test(t)) return "sucesso";
    if (/deseja|tem certeza|confirma/.test(t) && q(".swal2-cancel").some(visivel)) return "pergunta";
    return "falha"; // qualquer outro erro: repetir a aula
  }
  function fecharAviso() {
    const b = q(".swal2-confirm, .swal2-close").find(visivel);
    if (b) b.click();
  }
  // O SIAGE pode passar minutos carregando antes de mostrar "falha na operação".
  const ESPERA_MAXIMA = 180000;

  // Depois de clicar em Salvar: senha, confirmação e resposta do SIAGE
  async function confirmarSalvamento(senha) {
    const primeiro = await aguardar(() => {
      if (naLista()) return "lista";
      return q("input[type=password]").find(visivel) || (avisoNaTela() ? "aviso" : false);
    }, 8000);
    if (primeiro && primeiro.tagName) {
      if (!senha) return { ok: false, msg: "o SIAGE pediu a senha; digite-a na extensão", parar: true };
      const campoSenha = primeiro;
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(campoSenha, senha);
      for (const t of ["input", "keyup", "change", "blur"]) campoSenha.dispatchEvent(new Event(t, { bubbles: true }));
      await esperar(300);
      let caixa = campoSenha.closest(".modal-content, .modal, .ui-dialog, .p-dialog, .swal2-popup, [role=dialog], mat-dialog-container");
      if (!caixa) { caixa = campoSenha; for (let k = 0; k < 6 && caixa.parentElement; k++) { caixa = caixa.parentElement; if (q("button", caixa).length) break; } }
      const ok = q("button, input[type=submit], .swal2-confirm", caixa).filter((b) => visivel(b) && !b.disabled)
        .find((b) => /^(confirmar|salvar|ok|enviar|assinar|registrar|continuar|sim)/.test(norm(b.textContent || b.value)));
      if (ok) ok.click();
      else campoSenha.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter", keyCode: 13 }));
      await esperar(1000);
    } else if (!primeiro) {
      const confirmar = q(".modal.show .btn-primary, .ui-confirmdialog .ui-button, .p-confirm-dialog-accept").find(visivel);
      if (confirmar && /sim|confirmar|ok|salvar/.test(norm(confirmar.textContent))) confirmar.click();
    }

    // Espera o resultado: volta à lista (salvou) ou uma janela de aviso.
    const fim = Date.now() + ESPERA_MAXIMA;
    while (Date.now() < fim) {
      if (naLista()) return { ok: true };
      const aviso = avisoNaTela();
      if (aviso) {
        const tipo = tipoDoAviso(aviso);
        if (tipo === "senha") return { ok: false, msg: "senha não aceita: " + aviso, parar: true };
        if (tipo === "pergunta") { q(".swal2-confirm").find(visivel).click(); await esperar(1000); continue; }
        fecharAviso();
        await esperar(800);
        if (tipo === "sucesso") { await aguardar(naLista, 10000); return { ok: true }; }
        if (tipo === "repetida") return { ok: false, repetida: true, msg: aviso };
        return { ok: false, travou: true, msg: "o SIAGE respondeu: " + aviso };
      }
      // Senha errada mostrada embaixo do campo, sem janela
      if (q("input[type=password]").some(visivel) && tipoDoAviso(mensagemDoSistema()) === "senha")
        return { ok: false, msg: "senha não aceita: " + mensagemDoSistema(), parar: true };
      await esperar(400);
    }
    return { ok: false, travou: true, msg: "o SIAGE não respondeu" };
  }

  // ---------- Laço principal ----------
  let trabalhando = false;
  async function trabalhar() {
    if (trabalhando) return;
    trabalhando = true;
    try {
      const { handoff } = await chrome.storage.local.get("handoff");
      let job = await lerJob();
      const precisaLogin = !!(handoff || (job && job.status !== "concluido" && job.status !== "parado"));
      if (ehTelaDeLogin() && precisaLogin) {
        await preencherLogin(handoff || { cpf: "" });
        job = await lerJob();
      }

      if (job && job.status === "aguardando-login" && !ehTelaDeLogin()) {
        job.status = "rodando";
        await gravarJob(job);
      }
      const trabalhou = !!(job && job.status === "rodando");
      while (job && job.status === "rodando") {
        if (ehTelaAnoLetivo()) desenharPainel(job, "Selecionando ano letivo e matrícula…");
        const entrada = await entrarNoDiario();
        if (entrada === "login") {
          if (!precisaLogin) return;
          await preencherLogin(handoff || { cpf: "" });
          job = await lerJob();
          continue;
        }
        if (entrada === "navegando") return;

        const gi = job.grupos.findIndex((g) => g.aulas.some((a) => a.estado === "pendente"));
        if (gi < 0) { job.status = "concluido"; await gravarJob(job); break; }
        const grupo = job.grupos[gi];
        const nome = grupo.turma ? `${grupo.turma}${grupo.componente ? " · " + grupo.componente : ""}` : "turma aberta";

        if (grupo.turma) {
          desenharPainel(job, `Abrindo ${nome}…`);
          const r = await abrirTurma(job, gi);
          if (r === "navegando") return;
          if (r !== "ok") {
            grupo.tentativasAbertura = (grupo.tentativasAbertura || 0) + 1;
            await gravarJob(job);
            if (grupo.tentativasAbertura < 3) {
              desenharPainel(job, `Não achei ${nome} na listagem (tentativa ${grupo.tentativasAbertura}/3). Voltando à listagem…`);
              await esperar(1200);
              if (!ehListagemTurmas()) {
                location.href = URL_LISTAGEM;
                return;
              }
              continue;
            }
            const motivo = { "nao-achou": "turma não encontrada na listagem do SIAGE", "nao-abriu": "não consegui abrir a turma", errada: "a página aberta não é dessa turma/componente" }[r] || r;
            const afetadas = grupo.aulas.filter((a) => a.estado === "pendente");
            afetadas.forEach((a) => { a.estado = "erro"; a.msg = motivo; });
            await gravarJob(job);
            afetadas.forEach((a) => avisarMaestro(job, a, "failed"));
            continue;
          }
          grupo.tentativasAbertura = 0;
          await gravarJob(job);
        } else if (!naLista() && !naTelaDeCadastro()) {
          job.status = "parado"; await gravarJob(job);
          desenharPainel(job, "Abra a aba Frequência da turma e clique em Continuar na extensão.");
          return;
        }

        await marcarJaNaTela(job, gi);
        job = await lerJob();
        job.grupos[gi].aulas.sort((a, b) => String(a.data).localeCompare(String(b.data)));
        const ai = job.grupos[gi].aulas.findIndex((a) => a.estado === "pendente");
        if (ai < 0) { desenharPainel(job, `${nome}: nada pendente nesta turma.`); continue; }
        const aula = job.grupos[gi].aulas[ai];
        desenharPainel(job, `${nome}: ${dataBR(aula.data)} · ${aula.periodo}º per. · tempo ${aula.tempos.join(", ")}`);
        let r;
        try { r = await registrarAula(aula, !job.teste); } catch (e) { r = { aviso: "erro: " + e.message }; }

        job = await lerJob(); // pode ter sido parado pelo botão
        const a2 = job.grupos[gi].aulas[ai];
        if (job.teste) {
          const tudo = r.dataOk && r.temposFalha && !r.temposFalha.length;
          a2.estado = tudo ? "ok" : "erro";
          a2.msg = tudo ? "preenchida (teste)" : r.aviso || "tempo não encontrado";
          job.status = "parado";
          await gravarJob(job);
          desenharPainel(job, tudo ? "Teste: primeira aula preenchida sem salvar. Confira e clique em Cancelar." : "Teste falhou: " + a2.msg);
          return;
        }
        if (!r.salvou) {
          if (r.ja) {
            a2.estado = "ja";
            a2.msg = r.aviso || "já consta na Frequência";
            await gravarJob(job);
            avisarMaestro(job, a2, "already_registered");
            continue;
          }
          a2.estado = "erro";
          a2.msg = r.aviso || (r.temposFalha && r.temposFalha.length ? `tempo ${r.temposFalha.join(", ")} não existe` : "não salva");
          await gravarJob(job);
          avisarMaestro(job, a2, "failed");
          await voltarParaLista();
          continue;
        }
        const c = await confirmarSalvamento(await lerSenha());
        job = await lerJob();
        const a3 = job.grupos[gi].aulas[ai];
        a3.estado = c.ok ? "ok" : (c.repetida ? "ja" : "erro");
        a3.msg = c.repetida ? (c.msg || "já existe no SIAGE") : (c.msg || "");
        if (c.parar) job.status = "parado";
        if (c.travou) {
          // Faz sozinho o que o professor faria: F5 e continuar, repetindo a aula que travou.
          job.travamentos = (job.travamentos || 0) + 1;
          a3.estado = "pendente"; a3.msg = ""; a3.tentativas = (a3.tentativas || 0) + 1; // tenta de novo, sem limite (o professor pode clicar em Parar)
          await gravarJob(job);
          // Pausa crescente entre as tentativas (5s, 10s, 15s... até 60s) para não sobrecarregar o SIAGE
          const pausa = Math.min(60, 5 * job.travamentos);
          desenharPainel(job, `${c.msg} (tentativa ${job.travamentos}). Recarregando em ${pausa}s para repetir a aula…`);
          await esperar(pausa * 1000);
          if ((await lerJob()).status !== "rodando") return; // clicou em Parar durante a pausa
          location.reload();
          return;
        }
        if (c.ok || c.repetida) job.travamentos = 0;
        await gravarJob(job);
        if (!c.parar) avisarMaestro(job, a3, statusDoLivro(a3.estado));
        if (!c.ok && !c.parar) await voltarParaLista();
        await esperar(800);
      }
      if (job && trabalhou) {
        const extra = await chrome.storage.local.get("handoff");
        const temNotas = extra.handoff && Array.isArray(extra.handoff.grades) && extra.handoff.grades.length;
        if (job.status === "concluido" && temNotas && !ehTelaDeAvaliacoes()) {
          desenharPainel(job, "Abrindo Registro de Avaliações…");
          const dest = await irParaAvaliacoes(extra.handoff);
          if (dest === "navegando") return;
        }
        desenharPainel(job, job.status === "concluido" ? "Todas as aulas foram processadas. Confira no SIAGE." : "");
        if (job.status !== "rodando") {
          if (!temNotas) { try { await chrome.storage.session.remove("senha"); } catch (e) {} }
        }
      }
    } finally {
      trabalhando = false;
    }
  }

  chrome.runtime.onMessage.addListener((msg, _s, responder) => {
    if (msg && msg.tipo === "ping") responder({ ok: true });
    if (msg && msg.tipo === "iniciar") { trabalhar(); responder({ ok: true }); }
  });
  // Retoma sozinho depois de uma navegação/recarga ou troca de rota no Angular
  setTimeout(trabalhar, 1500);
  setInterval(async () => {
    if (trabalhando) return;
    const job = await lerJob();
    const ativo = job && (job.status === "rodando" || job.status === "aguardando-login");
    let handoff = null;
    try { handoff = (await chrome.storage.local.get("handoff")).handoff; } catch (e) {}
    if (!ativo && !handoff) return;
    trabalhar();
  }, 2500);
})();
