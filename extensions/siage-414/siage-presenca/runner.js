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
    const lab = q("label").filter(visivel).find((l) => re.test(norm(l.textContent)));
    if (!lab) return null;
    return lab.closest(".form-group, app-field") || lab.parentElement;
  }
  const naTelaDeCadastro = () => !!botaoComTexto(/^salvar/);
  const naLista = () => !naTelaDeCadastro() && !!botaoComTexto(/registrar frequencia/);
  function mensagemDoSistema() {
    const m = q(".toast-message, .toast-body, .ui-toast-detail, .ui-toast-summary, .p-toast-detail, .swal2-html-container, .swal2-title, .alert, .invalid-feedback, .ui-message-error")
      .filter(visivel).map((e) => e.textContent.trim()).filter(Boolean);
    return m.join(" ").slice(0, 160);
  }


  const URL_LISTAGEM = location.origin + "/diario/minhas-turmas/listagem-turmas";
  const dataBR = (iso) => iso.split("-").reverse().join("/");
  const lerJob = async () => (await chrome.storage.local.get("job")).job;
  const gravarJob = (job) => chrome.storage.local.set({ job });
  async function lerSenha() {
    try { return (await chrome.storage.session.get("senha")).senha || ""; } catch (e) { return ""; }
  }

  // "2ª SÉRIE H" -> reconhece "2ª SÉRIE H", "2a serie h", "2º Série - H"...
  function reTurma(turma) {
    const m = norm(turma).match(/(\d+)\s*[ªaº°o]?\s*serie\s*-?\s*([a-z])\b/);
    if (!m) return new RegExp(norm(turma).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
    return new RegExp(`(^|[^0-9])${m[1]}\\s*[ªaº°o]?\\s*serie\\s*-?\\s*${m[2]}([^a-z]|$)`);
  }
  // "Práticas Integradoras I" não pode casar com "Práticas Integradoras II"
  const APELIDOS = { isc: "Inovação Social e Científica" };
  const nomeComponente = (c) => APELIDOS[norm(c)] || c;
  const reComp = (comp) => new RegExp(`(^|[^a-z])${norm(comp).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}([^a-z]|$)`);

  // Confere no cabeçalho da página de frequência se é a turma/componente certos
  function paginaDaTurma(grupo) {
    const h4 = q("h4").map((e) => norm(e.innerText || e.textContent)).join(" | ");
    const comp = q("strong").filter((s) => /componente curricular/.test(norm(s.textContent)))
      .map((s) => norm(s.parentElement.innerText || s.parentElement.textContent)).join(" | ");
    return reTurma(grupo.turma).test(h4) && (!grupo.componente || reComp(nomeComponente(grupo.componente)).test(comp));
  }
  const naPaginaDeFrequencia = () => /\/turma\/[^/]+\/frequencia/.test(location.pathname);

  // ---------- Painel ----------
  let painel;
  function desenharPainel(job, atual) {
    if (!painel || !document.body.contains(painel)) {
      painel = document.createElement("div");
      painel.id = "siage-fila-painel";
      painel.style.cssText = "position:fixed;right:16px;bottom:16px;z-index:2147483647;width:340px;max-height:60vh;overflow:auto;background:#fff;color:#1f2937;border:1px solid #d1d5db;border-radius:10px;box-shadow:0 8px 24px rgba(0,0,0,.2);font:13px system-ui,sans-serif;padding:12px";
      document.body.appendChild(painel);
    }
    const rodando = job.status === "rodando";
    const linhas = job.grupos.map((g) => {
      const ok = g.aulas.filter((a) => a.estado === "ok").length;
      const erro = g.aulas.filter((a) => a.estado === "erro").length;
      const nome = g.turma ? `${g.turma}${g.componente ? " · " + g.componente : ""}` : "Turma aberta";
      return `<div style="padding:3px 0;border-top:1px solid #f3f4f6">${nome}: <b style="color:#15803d">${ok}✔</b>${erro ? ` <b style="color:#b91c1c">${erro}✖</b>` : ""} de ${g.aulas.length}</div>`;
    }).join("");
    const erros = job.grupos.flatMap((g) => g.aulas.filter((a) => a.estado === "erro").map((a) => `${g.turma || ""} ${dataBR(a.data)}: ${a.msg}`)).slice(-8);
    painel.innerHTML = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
      <b>${rodando ? "Registrando frequência" : job.status === "concluido" ? "Concluído" : "Parado"}</b>
      <button type="button" id="siage-fila-botao" style="border:1px solid ${rodando ? "#b91c1c" : "#6b7280"};color:${rodando ? "#b91c1c" : "#374151"};background:#fff;border-radius:6px;padding:2px 8px;cursor:pointer">${rodando ? "Parar" : "Fechar"}</button></div>
      <div style="color:#1d4ed8;margin-bottom:6px">${atual || ""}</div>${linhas}
      ${erros.length ? `<div style="margin-top:6px;color:#b91c1c;font-size:12px">${erros.map((e) => "✖ " + e.replace(/</g, "&lt;")).join("<br>")}</div>` : ""}`;
    painel.querySelector("#siage-fila-botao").onclick = async () => {
      if (rodando) { const j = await lerJob(); j.status = "parado"; await gravarJob(j); desenharPainel(j, "Parando depois da aula atual…"); }
      else painel.remove();
    };
  }

  // ---------- Abrir a turma ----------
  async function acharNaListagem(grupo) {
    const rt = reTurma(grupo.turma);
    // Guarda na aba em que ponto da busca está (a troca de página pode recarregar a tela)
    const chave = "siageBusca:" + norm(grupo.turma) + "|" + norm(grupo.componente);
    let paginas = +(sessionStorage.getItem(chave) || 0);
    if (!paginas) {
      // começa pela primeira página da listagem
      const primeira = q(".ngx-pagination li a, .pagination li a, pagination-controls a").find((a) => norm(a.textContent).replace(/page/g, "").trim() === "1");
      sessionStorage.setItem(chave, "1");
      paginas = 1;
      if (primeira && !primeira.closest("li.current")) { primeira.click(); await esperar(1500); }
    }
    for (; paginas < 30; paginas++) {
      await aguardar(() => q("tbody tr").some(visivel), 8000);
      // Listagem do SIAGE: uma linha por turma+componente; colunas TURMA ("3ª SÉRIE L - ANÁLISES CLÍNICAS") e COMPONENTE CURRICULAR
      const candidatos = q("tbody tr").filter((tr) => visivel(tr) && !tr.closest("#siage-fila-painel")).filter((tr) => {
        const celulas = q("td", tr).map((td) => norm(td.innerText || td.textContent));
        return celulas.some((c) => rt.test(c)) && (!grupo.componente || celulas.some((c) => c === norm(nomeComponente(grupo.componente))));
      });
      if (candidatos.length) { sessionStorage.removeItem(chave); return candidatos[0]; }
      const proxima = q("li.pagination-next:not(.disabled) a, .pagination-next:not(.disabled) a, a[aria-label*='Next'], a[aria-label*='Próxima']").find(visivel);
      if (!proxima) { sessionStorage.removeItem(chave); return null; }
      sessionStorage.setItem(chave, String(paginas + 1));
      const antes = document.body.innerText.length;
      proxima.click();
      await aguardar(() => document.body.innerText.length !== antes, 4000);
      await esperar(800);
    }
    return null;
  }

  async function abrirTurma(job, gi) {
    const grupo = job.grupos[gi];
    if (naPaginaDeFrequencia() && paginaDaTurma(grupo)) return "ok";
    const chaveAbrindo = "siageAbrindo:" + norm(grupo.turma) + "|" + norm(grupo.componente);
    const idNaUrl = (location.pathname.match(/\/turma\/([0-9a-f-]{8,})/i) || [])[1];
    if (idNaUrl && !grupo.turmaId) {
      // Voltou de um clique em "Visualizar" que recarregou a página
      await aguardar(() => paginaDaTurma(grupo), 6000);
      if (paginaDaTurma(grupo) || sessionStorage.getItem(chaveAbrindo)) {
        grupo.turmaId = idNaUrl;
        sessionStorage.removeItem(chaveAbrindo);
        await gravarJob(job);
      }
    }
    if (grupo.turmaId) {
      const alvo = `${URL_LISTAGEM}/turma/${grupo.turmaId}/frequencia`;
      if (location.href !== alvo) { location.href = alvo; return "navegando"; }
      await aguardar(() => paginaDaTurma(grupo), 10000);
      return paginaDaTurma(grupo) ? "ok" : "errada";
    }
    if (!/\/listagem-turmas\/?$/.test(location.pathname)) { location.href = URL_LISTAGEM; return "navegando"; }
    const linha = await acharNaListagem(grupo);
    if (!linha) return "nao-achou";
    const link = linha.querySelector("#btn-visualizar, button[title=Visualizar]") || q("a[href*='/turma/']", linha)[0]
      || q("button, a", linha).find((b) => /visualizar|acessar|abrir|frequencia|diario/.test(norm(b.title + " " + b.textContent)))
      || q("button, a", linha)[0] || linha;
    sessionStorage.setItem(chaveAbrindo, "1");
    link.click();
    const id = await aguardar(() => (location.pathname.match(/\/turma\/([0-9a-f-]{8,})/i) || [])[1], 10000);
    if (!id) return "nao-abriu";
    grupo.turmaId = id;
    sessionStorage.removeItem(chaveAbrindo);
    await gravarJob(job);
    const aba = await aguardar(() => q("a#frequencia, a.nav-link").find((a) => visivel(a) && /^frequencia$/.test(norm(a.textContent))), 8000);
    if (aba) aba.click(); else { location.href = `${URL_LISTAGEM}/turma/${id}/frequencia`; return "navegando"; }
    await aguardar(() => naPaginaDeFrequencia() && paginaDaTurma(grupo), 10000);
    return paginaDaTurma(grupo) ? "ok" : "errada";
  }

  // ---------- Registrar uma aula (tela Registrar Frequência) ----------
  async function registrarAula(aula, salvar) {
    // Volta para a lista se ficou em outra tela
    if (!naLista() && !naTelaDeCadastro()) await aguardar(() => naLista() || naTelaDeCadastro(), 8000);
    const [ano, mes, dia] = aula.data.split("-").map(Number);
    const resultado = { dataOk: false, temposOk: [], temposFalha: [...aula.tempos], salvou: false, aviso: "" };

    // 0) Se ainda está na lista, abre "Registrar Frequência"
    if (!botaoComTexto(/^salvar/)) {
      const registrar = botaoComTexto(/registrar frequencia/);
      if (registrar) {
        registrar.click();
        await aguardar(() => botaoComTexto(/^salvar/), 10000);
        await esperar(500);
      }
    }
    if (!botaoComTexto(/^salvar/) && !campo(/^tempo/)) {
      resultado.aviso = "Abra a tela de Registrar Frequência da turma.";
      return resultado;
    }

    // ---------- 1) Data (p-calendar) ----------
    const MESES = ["janeiro","fevereiro","marco","abril","maio","junho","julho","agosto","setembro","outubro","novembro","dezembro"];
    const MESES_EN = ["january","february","march","april","may","june","july","august","september","october","november","december"];
    const blocoData = campo(/^data/);
    const inputData = blocoData && (blocoData.querySelector("p-calendar input, input"));
    if (inputData) {
      const painelAberto = () => q(".ui-datepicker, .p-datepicker").find(visivel);
      inputData.focus();
      inputData.click();
      let painel = await aguardar(painelAberto, 2000);
      if (!painel) {
        const gatilho = blocoData.querySelector(".ui-datepicker-trigger, .p-datepicker-trigger, button");
        if (gatilho) gatilho.click();
        painel = await aguardar(painelAberto, 3000);
      }
      if (painel) {
        // Lê mês/ano do cabeçalho. Cada um pode ser texto (span) ou lista (select, com yearNavigator).
        const lerMesAno = () => {
          const eMes = painel.querySelector(".ui-datepicker-month, .p-datepicker-month");
          const eAno = painel.querySelector(".ui-datepicker-year, .p-datepicker-year");
          if (!eMes || !eAno) return null;
          let m;
          if (eMes.tagName === "SELECT") m = eMes.selectedIndex + 1;
          else {
            const t = norm(eMes.textContent);
            m = Math.max(MESES.indexOf(t), MESES_EN.indexOf(t), t ? MESES.findIndex((x) => x.startsWith(t.slice(0, 3))) : -1) + 1;
          }
          const a = eAno.tagName === "SELECT" ? parseInt(eAno.value, 10) : parseInt(eAno.textContent, 10);
          return m && a > 1900 && a < 2100 ? { m, a, eMes, eAno } : null;
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
          if (atual.a !== ano && atual.eAno.tagName === "SELECT" && escolherNaLista(atual.eAno, ano)) { await esperar(200); continue; }
          if (atual.m !== mes && atual.eMes.tagName === "SELECT" && escolherNaLista(atual.eMes, mes - 1)) { await esperar(200); continue; }
          const diff = (ano - atual.a) * 12 + (mes - atual.m);
          if (diff === 0) break;
          // Se o cabeçalho não muda depois de clicar, algo está errado: para em vez de sair navegando
          const chave = atual.m + "/" + atual.a;
          repetidas = chave === anterior ? repetidas + 1 : 0;
          anterior = chave;
          if (repetidas >= 3) break;
          const nav = painel.querySelector(diff > 0 ? ".ui-datepicker-next, .p-datepicker-next" : ".ui-datepicker-prev, .p-datepicker-prev");
          if (!nav) break;
          nav.click();
          await esperar(200);
        }
        const conferido = lerMesAno();
        if (!conferido || conferido.m !== mes || conferido.a !== ano) {
          resultado.aviso = "Não consegui chegar ao mês certo no calendário.";
          if (visivel(painel)) document.body.click();
          return resultado;
        }
        const celula = q("td", painel).find((td) =>
          !/other-month|ui-datepicker-other|p-datepicker-other/.test(td.className) && norm(td.textContent) === String(dia));
        const alvo = celula && celula.querySelector("a, span");
        if (alvo && !/ui-state-disabled|p-disabled/.test(alvo.className + " " + celula.className)) {
          alvo.click();
          await esperar(300);
          // Confere a data que ficou no campo antes de seguir (nunca salva data errada)
          const dd = String(dia).padStart(2, "0"), mm = String(mes).padStart(2, "0");
          const valor = (inputData.value || "").replace(/\s/g, "");
          resultado.dataOk = [`${dd}/${mm}/${ano}`, `${dd}/${mm}/${String(ano).slice(2)}`, `${ano}-${mm}-${dd}`].some((f) => valor.includes(f));
          if (!resultado.dataOk) resultado.aviso = `O campo ficou com "${inputData.value}", não com a data pedida.`;
        } else {
          resultado.aviso = "O dia escolhido está bloqueado no calendário do SIAGE.";
        }
        if (visivel(painel)) document.body.click();
      }
    }
    if (!resultado.dataOk) {
      if (!resultado.aviso) resultado.aviso = "Não consegui escolher a data no calendário.";
      return resultado;
    }
    await esperar(600); // o SIAGE pode carregar os tempos depois da data

    // ---------- 1b) Período (p-autocomplete) ----------
    if (aula.periodo) {
      const blocoPer = campo(/^periodo/);
      if (blocoPer) {
        const inputPer = blocoPer.querySelector("input");
        const itemPer = "li.ui-autocomplete-list-item, li.p-autocomplete-item";
        const casaPer = (li) => new RegExp(`^${aula.periodo}\\s*(º|°|o)?\\s*periodo`).test(norm(li.textContent));
        const jaTem = () => inputPer && new RegExp(`^${aula.periodo}\\D`).test(norm(inputPer.value));
        if (!jaTem()) {
          const abrir = () => {
            const dd = blocoPer.querySelector(".ui-autocomplete-dropdown, .p-autocomplete-dropdown");
            if (dd) dd.click(); else if (inputPer) { inputPer.focus(); inputPer.click(); }
          };
          abrir();
          let item = await aguardar(() => q(itemPer).filter(visivel).find(casaPer), 3000);
          if (!item && inputPer) {
            // alguns autocompletes só listam ao digitar
            inputPer.focus();
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(inputPer, String(aula.periodo));
            inputPer.dispatchEvent(new Event("input", { bubbles: true }));
            inputPer.dispatchEvent(new KeyboardEvent("keyup", { bubbles: true, key: String(aula.periodo) }));
            item = await aguardar(() => q(itemPer).filter(visivel).find(casaPer), 4000);
          }
          if (item) { item.click(); await esperar(400); }
        }
        if (!jaTem()) {
          resultado.aviso = `Não consegui escolher o ${aula.periodo}º Período.`;
          return resultado;
        }
        await esperar(400);
      }
    }

    // ---------- 2) Tempo (p-multiselect ou p-dropdown) ----------
    const casaTempo = (texto, t) => new RegExp(`(^|[^0-9])${t}\\s*(º|°|o|a|ª)?(\\s|$|[^0-9:])`).test(norm(texto).replace(/[º°ª]/g, "º"));
    const blocoTempo = await aguardar(() => campo(/^tempo/), 4000);
    const seletor = blocoTempo && blocoTempo.querySelector(".ui-multiselect, .p-multiselect, .ui-dropdown, .p-dropdown");
    if (seletor) {
      const multi = /multiselect/.test(seletor.className);
      const itemSel = multi ? "li.ui-multiselect-item, li.p-multiselect-item" : "li.ui-dropdown-item, li.p-dropdown-item";
      const abrir = async () => {
        if (!q(itemSel).some(visivel)) { seletor.click(); await aguardar(() => q(itemSel).some(visivel), 3000); }
      };
      resultado.temposFalha = [];
      for (const t of aula.tempos) {
        await abrir();
        const item = await aguardar(() => q(itemSel).filter(visivel).find((li) => casaTempo(li.textContent, t)), 4000);
        if (!item) { resultado.temposFalha.push(t); continue; }
        const marcado = /ui-state-highlight|p-highlight/.test(item.className) || item.getAttribute("aria-selected") === "true" || item.getAttribute("aria-checked") === "true";
        if (!marcado) item.click();
        resultado.temposOk.push(t);
        await esperar(200);
        if (!multi) break;
      }
      // fecha a lista
      if (q(itemSel).some(visivel)) { seletor.click(); await esperar(200); }
      if (q(itemSel).some(visivel)) document.body.click();
    } else {
      resultado.aviso = "Não encontrei o campo Tempo.";
      return resultado;
    }

    // ---------- 3) Salvar ----------
    if (salvar && !resultado.temposFalha.length) {
      const salvar = await aguardar(() => { const b = botaoComTexto(/^salvar/); return b && !b.disabled ? b : null; }, 5000);
      if (salvar) { salvar.click(); resultado.salvou = true; }
      else resultado.aviso = "O botão Salvar está desativado; confira os campos.";
    }
    return resultado;

  }


  async function voltarParaLista() {
    if (naLista()) return true;
    const cancelar = botaoComTexto(/^(cancelar|voltar)/);
    if (cancelar) cancelar.click(); else history.back();
    await esperar(800);
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
      let job = await lerJob();
      const trabalhou = !!(job && job.status === "rodando");
      while (job && job.status === "rodando") {
        const gi = job.grupos.findIndex((g) => g.aulas.some((a) => a.estado === "pendente"));
        if (gi < 0) { job.status = "concluido"; await gravarJob(job); break; }
        const grupo = job.grupos[gi];
        const nome = grupo.turma ? `${grupo.turma}${grupo.componente ? " · " + grupo.componente : ""}` : "turma aberta";

        if (grupo.turma) {
          desenharPainel(job, `Abrindo ${nome}…`);
          const r = await abrirTurma(job, gi);
          if (r === "navegando") return; // a página vai recarregar e o trabalho continua sozinho
          if (r !== "ok") {
            const motivo = { "nao-achou": "turma não encontrada na listagem do SIAGE", "nao-abriu": "não consegui abrir a turma", errada: "a página aberta não é dessa turma/componente" }[r] || r;
            grupo.aulas.forEach((a) => { if (a.estado === "pendente") { a.estado = "erro"; a.msg = motivo; } });
            await gravarJob(job);
            continue;
          }
        } else if (!naLista() && !naTelaDeCadastro()) {
          job.status = "parado"; await gravarJob(job);
          desenharPainel(job, "Abra a aba Frequência da turma e clique em Continuar na extensão.");
          return;
        }

        const ai = grupo.aulas.findIndex((a) => a.estado === "pendente");
        const aula = grupo.aulas[ai];
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
          a2.estado = "erro";
          a2.msg = r.aviso || (r.temposFalha && r.temposFalha.length ? `tempo ${r.temposFalha.join(", ")} não existe` : "não salva");
          await gravarJob(job);
          await voltarParaLista();
          continue;
        }
        const c = await confirmarSalvamento(await lerSenha());
        job = await lerJob();
        const a3 = job.grupos[gi].aulas[ai];
        a3.estado = c.ok ? "ok" : "erro";
        a3.msg = c.msg || "";
        if (c.repetida && a3.tentativas) {
          // Já tinha travado antes: o SIAGE gravou numa das tentativas anteriores.
          a3.estado = "ok"; a3.msg = "já estava registrada (gravada numa tentativa anterior)";
        }
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
        if (c.ok) job.travamentos = 0;
        await gravarJob(job);
        if (!c.ok && !c.parar) await voltarParaLista();
        await esperar(800);
      }
      if (job && trabalhou) {
        desenharPainel(job, job.status === "concluido" ? "Todas as aulas foram processadas. Confira no SIAGE." : "");
        if (job.status !== "rodando") { try { await chrome.storage.session.remove("senha"); } catch (e) {} }
      }
    } finally {
      trabalhando = false;
    }
  }

  chrome.runtime.onMessage.addListener((msg, _s, responder) => {
    if (msg && msg.tipo === "ping") responder({ ok: true });
    if (msg && msg.tipo === "iniciar") { trabalhar(); responder({ ok: true }); }
  });
  // Retoma sozinho depois de uma navegação/recarga
  setTimeout(trabalhar, 1500);
})();
