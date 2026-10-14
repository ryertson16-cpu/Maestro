// Roda no mundo da página (Angular). O combo de mês só reage a clique daqui.
(() => {
  if (window.__siageBridge) return;
  window.__siageBridge = true;

  const MESES = ["janeiro","fevereiro","marco","abril","maio","junho","julho","agosto","setembro","outubro","novembro","dezembro"];
  const nrm = (s) => (s || "").toString().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\s+/g, " ").trim().toLowerCase();
  const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
  const visivel = (el) => !!(el && (el.offsetWidth || el.offsetHeight || el.getClientRects().length));

  function clickEl(el) {
    if (!el) return false;
    const r = el.getBoundingClientRect();
    const x = r.left + Math.max(4, r.width / 2);
    const y = r.top + Math.max(4, r.height / 2);
    const opts = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y, buttons: 1 };
    try { el.dispatchEvent(new PointerEvent("pointerdown", opts)); } catch (e) {}
    el.dispatchEvent(new MouseEvent("mousedown", opts));
    try { el.dispatchEvent(new PointerEvent("pointerup", opts)); } catch (e) {}
    el.dispatchEvent(new MouseEvent("mouseup", opts));
    el.dispatchEvent(new MouseEvent("click", opts));
    if (typeof el.click === "function") el.click();
    const topo = document.elementFromPoint(x, y);
    if (topo && topo !== el && !topo.closest("#siage-fila-painel")) {
      if (typeof topo.click === "function") topo.click();
    }
    return true;
  }

  function clickPonto(x, y) {
    const el = document.elementFromPoint(x, y);
    if (!el) return false;
    return clickEl(el);
  }

  function acharDialog() {
    const lista = [...document.querySelectorAll(".p-dialog, .ui-dialog, .modal, [role=dialog]")];
    return lista.find((d) => visivel(d) && /selecione um mes e uma data/.test(nrm(d.innerText || ""))) || null;
  }

  function pareceCombo(el) {
    if (!el || !visivel(el)) return false;
    const r = el.getBoundingClientRect();
    return r.width >= 90 && r.width <= 420 && r.height >= 24 && r.height <= 72;
  }

  function acharComboMes() {
    const dlg = acharDialog() || document.body;
    const lab = [...dlg.querySelectorAll("label")].find((l) => /^mes\b/.test(nrm(l.textContent)) && nrm(l.textContent).length < 40);
    const acc = [];
    const add = (el) => {
      if (!el) return;
      const caixa = pareceCombo(el) ? el : (pareceCombo(el.parentElement) ? el.parentElement : null);
      if (caixa && !acc.includes(caixa)) acc.push(caixa);
    };
    if (lab) {
      const grupo = lab.parentElement;
      if (grupo) {
        add(grupo.querySelector("ng-select, p-dropdown, .p-dropdown, .ng-select, [role=combobox]"));
        add(grupo.querySelector("input:not([type=hidden]):not([type=checkbox]), select"));
      }
    }
    [...dlg.querySelectorAll("ng-select, p-dropdown, .p-dropdown, .ng-select, [role=combobox], input:not([type=hidden])")].forEach((el) => {
      const r = el.getBoundingClientRect();
      const top = dlg.getBoundingClientRect().top;
      if (r.top < top + 230) add(el);
    });
    acc.sort((a, b) => a.getBoundingClientRect().width - b.getBoundingClientRect().width);
    return acc[0] || null;
  }

  function textoCombo(combo) {
    if (!combo) return "";
    const rotulo = combo.querySelector(".p-dropdown-label, .ng-value-label, .ng-value, input");
    const bruto = (rotulo && (rotulo.value || rotulo.textContent)) || combo.innerText || "";
    const t = nrm(bruto);
    return MESES.find((m) => t === m || t.startsWith(m) || t.split(/[^a-z]+/).includes(m)) || "";
  }

  function tituloCalendario() {
    const dlg = acharDialog();
    const t = nrm((dlg && dlg.innerText) || "");
    const m = t.match(/(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+d\s+s\s+t/);
    return m ? m[1] : "";
  }

  function acharListaMeses() {
    return [...document.querySelectorAll("[role=listbox], .p-dropdown-panel, .ng-dropdown-panel, .cdk-overlay-pane, ul")].find((p) => {
      if (!visivel(p) || p.closest("#siage-fila-painel")) return false;
      const r = p.getBoundingClientRect();
      if (r.height < 50 || r.height > 520) return false;
      const t = nrm(p.innerText || "");
      return MESES.filter((m) => t.includes(m)).length >= 2;
    }) || null;
  }

  function opcaoMes(tela, lista) {
    const alvo = nrm(tela);
    const raiz = lista || document;
    const opts = [...raiz.querySelectorAll("li, [role=option], .p-dropdown-item, .ng-option")].filter(visivel);
    return opts.find((el) => nrm(el.textContent) === alvo) || null;
  }

  function fecharAlerta() {
    const t = nrm(document.body.innerText || "");
    if (!/nao e possivel selecionar uma data posterior|data posterior a data atual/.test(t)) return false;
    const btn = [...document.querySelectorAll("button, .p-button, .swal2-confirm, a")].find((b) => {
      const x = nrm(b.textContent);
      return visivel(b) && (x === "ok" || x === "sim");
    });
    if (btn) { clickEl(btn); return true; }
    return false;
  }

  async function escolherMesNaPagina(tela) {
    const alvo = nrm(tela);
    if (fecharAlerta()) await dormir(400);

    const combo = acharComboMes();
    if (combo && textoCombo(combo) === alvo && tituloCalendario() === alvo) return true;
    if (!combo) return false;

    const sel = combo.tagName === "SELECT" ? combo : combo.querySelector("select");
    if (sel) {
      const op = [...sel.options].find((o) => nrm(o.textContent) === alvo);
      if (op) {
        sel.value = op.value;
        sel.dispatchEvent(new Event("input", { bubbles: true }));
        sel.dispatchEvent(new Event("change", { bubbles: true }));
        await dormir(500);
        if (tituloCalendario() === alvo) return true;
      }
    }

    const r = combo.getBoundingClientRect();
    clickPonto(r.right - 10, r.top + r.height / 2);
    await dormir(450);
    let lista = acharListaMeses();
    if (!lista) {
      clickPonto(r.left + 24, r.top + r.height / 2);
      await dormir(350);
      lista = acharListaMeses();
    }

    if (lista) {
      let item = opcaoMes(tela, lista);
      for (let i = 0; i < 45 && !item; i++) {
        lista.dispatchEvent(new WheelEvent("wheel", { bubbles: true, cancelable: true, deltaY: 90 }));
        [lista, ...lista.querySelectorAll("*")].forEach((s) => {
          if (s.scrollHeight > s.clientHeight + 8) s.scrollTop = Math.min(s.scrollHeight, s.scrollTop + 48);
        });
        await dormir(70);
        lista = acharListaMeses() || lista;
        item = opcaoMes(tela, lista) || opcaoMes(tela);
      }
      if (item) {
        try { item.scrollIntoView({ block: "nearest" }); } catch (e) {}
        clickEl(item);
        await dormir(700);
        if (tituloCalendario() === alvo) return true;
      }
    }

    clickPonto(r.left + 30, r.top + r.height / 2);
    await dormir(200);
    const campo = document.activeElement;
    if (campo && "value" in campo) {
      campo.focus();
      try { document.execCommand("selectAll", false, null); } catch (e) {}
      try { document.execCommand("insertText", false, tela); } catch (e) {
        const proto = campo.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
        const setter = Object.getOwnPropertyDescriptor(proto, "value")?.set;
        if (setter) setter.call(campo, tela);
        else campo.value = tela;
        campo.dispatchEvent(new InputEvent("input", { bubbles: true, data: tela, inputType: "insertText" }));
      }
      await dormir(250);
      const marcado = opcaoMes(tela, acharListaMeses() || document);
      if (marcado) clickEl(marcado);
      else {
        const opts = { bubbles: true, cancelable: true, key: "Enter", code: "Enter", keyCode: 13, which: 13 };
        campo.dispatchEvent(new KeyboardEvent("keydown", opts));
        campo.dispatchEvent(new KeyboardEvent("keyup", opts));
      }
      await dormir(700);
    }
    return tituloCalendario() === alvo;
  }

  function clickSo(el) {
    if (!el) return false;
    const r = el.getBoundingClientRect();
    const x = r.left + Math.max(4, r.width / 2);
    const y = r.top + Math.max(4, r.height / 2);
    const opts = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y, buttons: 1 };
    try { el.dispatchEvent(new PointerEvent("pointerdown", opts)); } catch (e) {}
    el.dispatchEvent(new MouseEvent("mousedown", opts));
    try { el.dispatchEvent(new PointerEvent("pointerup", opts)); } catch (e) {}
    el.dispatchEvent(new MouseEvent("mouseup", opts));
    el.dispatchEvent(new MouseEvent("click", opts));
    if (typeof el.click === "function") el.click();
    return true;
  }

  function recusarCancelar() {
    const t = nrm(document.body.innerText || "");
    if (!/cancelar o preenchimento/.test(t)) return false;
    const nao = [...document.querySelectorAll("button")].find((b) => visivel(b) && nrm(b.textContent) === "nao");
    if (nao) { clickSo(nao); return true; }
    return false;
  }

  function inputDataFreq() {
    return [...document.querySelectorAll("input")].find((el) => {
      if (!visivel(el) || el.closest("#siage-fila-painel")) return false;
      const ph = nrm(el.getAttribute("placeholder") || el.placeholder || "");
      return /dd.?mm.?aa/.test(ph);
    }) || null;
  }

  function iconeCalendarioFreq() {
    const input = inputDataFreq();
    if (!input) return null;
    const ir = input.getBoundingClientRect();
    const raiz = input.closest("p-calendar, .p-calendar, bs-datepicker, .input-group, .p-inputgroup, .p-field, .form-group, app-field") || input.parentElement || document.body;
    const candidatos = [...raiz.querySelectorAll("button, .p-datepicker-trigger, [class*=calendar], span, i, a")].filter(visivel);
    return candidatos.find((el) => {
      const r = el.getBoundingClientRect();
      return r.left >= ir.right - 14 && r.left <= ir.right + 56 && Math.abs(r.top - ir.top) < 28 && r.width <= 56 && r.height <= 56;
    }) || raiz.querySelector(".pi-calendar, .fa-calendar, [class*=pi-calendar]")?.closest("button, span, a") || null;
  }

  function painelMes() {
    const cand = [...document.querySelectorAll("bs-datepicker-container, .bs-datepicker, .p-datepicker, ngb-datepicker, .cdk-overlay-pane, [class*=datepicker], div")];
    const ok = cand.filter((el) => {
      if (!visivel(el) || el.closest("#siage-fila-painel")) return false;
      const t = nrm(el.innerText || "");
      if (t.length < 30 || t.length > 1200) return false;
      const temMes = MESES.some((m) => t.includes(m)) && /20\d{2}/.test(t);
      return temMes && /d\s+s\s+t\s+q/.test(t);
    });
    ok.sort((a, b) => {
      const aa = a.getBoundingClientRect();
      const bb = b.getBoundingClientRect();
      return (aa.width * aa.height) - (bb.width * bb.height);
    });
    return ok[0] || null;
  }

  function mesAnoPainel(painel) {
    const t = nrm((painel && painel.innerText) || "").slice(0, 400);
    const mi = MESES.findIndex((m) => t.includes(m));
    const ano = parseInt((t.match(/20\d{2}/) || [])[0], 10);
    return { m: mi + 1, a: ano || 0 };
  }

  function setaPainel(painel, dir) {
    if (!painel) return null;
    const prev = painel.querySelector("button.previous, .previous, .p-datepicker-prev, .ui-datepicker-prev, [class*=left]");
    const next = painel.querySelector("button.next, .next, .p-datepicker-next, .ui-datepicker-next, [class*=right]");
    if (dir === "prev" && visivel(prev)) return prev;
    if (dir === "next" && visivel(next)) return next;
    const box = painel.getBoundingClientRect();
    const botoes = [...painel.querySelectorAll("button, a, span")].filter((el) => {
      if (!visivel(el)) return false;
      const r = el.getBoundingClientRect();
      const txt = nrm(el.textContent || "");
      if (/hoje|limpar/.test(txt)) return false;
      return r.top < box.top + 56 && r.width <= 44 && r.height <= 44;
    });
    const simbolos = botoes.filter((el) => /^(‹|›|<|>|«|»)$/.test((el.textContent || "").trim()));
    if (dir === "prev") {
      return simbolos.find((el) => /^(‹|<|«)$/.test((el.textContent || "").trim())) || botoes[0] || null;
    }
    return simbolos.find((el) => /^(›|>|»)$/.test((el.textContent || "").trim())) || botoes[botoes.length - 1] || null;
  }

  function diaNoPainel(painel, dia) {
    const pad = String(Number(dia));
    const nos = [...painel.querySelectorAll("span, td, button, div")].filter((el) => {
      if (!visivel(el)) return false;
      if (/disabled|muted|other|outside|is-other/.test(el.className || "")) return false;
      const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).join("");
      const t = (own || el.textContent || "").trim();
      if (t !== pad) return false;
      const r = el.getBoundingClientRect();
      return r.width >= 14 && r.width <= 56 && r.height >= 14 && r.height <= 56;
    });
    const vivos = nos.filter((el) => {
      const op = parseFloat(getComputedStyle(el).opacity || "1");
      return op > 0.7;
    });
    return (vivos.length ? vivos : nos)[0] || null;
  }

  function valorData(input) {
    return ((input && input.value) || "").replace(/\s/g, "");
  }

  function dataConfere(valor, br, dd, mm, ano) {
    return [br, `${dd}/${mm}/${String(ano).slice(2)}`, `${ano}-${mm}-${dd}`].some((f) => valor.includes(f));
  }

  async function escreverData(campo, texto) {
    campo.removeAttribute("readonly");
    campo.readOnly = false;
    campo.focus();
    try { document.execCommand("selectAll", false, null); } catch (e) {}
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")?.set;
    if (setter) setter.call(campo, "");
    campo.dispatchEvent(new Event("input", { bubbles: true }));
    try { document.execCommand("insertText", false, texto); } catch (e) {}
    if (!valorData(campo) && setter) setter.call(campo, texto);
    campo.dispatchEvent(new InputEvent("input", { bubbles: true, data: texto, inputType: "insertText" }));
    campo.dispatchEvent(new Event("change", { bubbles: true }));
  }

  async function escolherDataNoQuadro(ano, mes, dia) {
    recusarCancelar();
    if (!painelMes()) {
      const input = inputDataFreq();
      if (input) clickSo(input);
      await dormir(400);
    }
    let painel = null;
    for (let i = 0; i < 20; i++) {
      recusarCancelar();
      painel = painelMes();
      if (painel) break;
      await dormir(200);
    }
    if (!painel) return false;

    for (let i = 0; i < 24; i++) {
      recusarCancelar();
      painel = painelMes() || painel;
      const atual = mesAnoPainel(painel);
      if (atual.m === mes && atual.a === ano) break;
      if (!atual.m) return false;
      const diff = (ano - atual.a) * 12 + (mes - atual.m);
      const seta = setaPainel(painel, diff > 0 ? "next" : "prev");
      if (!seta) return false;
      clickSo(seta);
      await dormir(400);
    }
    painel = painelMes() || painel;
    const fim = mesAnoPainel(painel);
    if (fim.m !== mes || fim.a !== ano) return false;
    const cel = diaNoPainel(painel, dia);
    if (!cel) return false;
    clickSo(cel);
    await dormir(400);
    recusarCancelar();
    return true;
  }

  async function preencherDataFreq(iso, dataBr) {
    recusarCancelar();
    let ano, mes, dia, br;
    const brIn = String(dataBr || "").replace(/\s/g, "");
    if (/^\d{2}\/\d{2}\/\d{4}$/.test(brIn)) {
      const p = brIn.split("/");
      dia = +p[0]; mes = +p[1]; ano = +p[2];
      br = brIn;
    } else {
      [ano, mes, dia] = String(iso).split("-").map(Number);
      br = `${String(dia).padStart(2, "0")}/${String(mes).padStart(2, "0")}/${ano}`;
    }
    const dd = String(dia).padStart(2, "0");
    const mm = String(mes).padStart(2, "0");
    const input = inputDataFreq();
    if (!input) return { ok: false, aviso: "Não achei o campo Data." };
    if (dataConfere(valorData(input), br, dd, mm, ano)) return { ok: true };

    await escreverData(input, br);
    await dormir(200);
    if (dataConfere(valorData(inputDataFreq() || input), br, dd, mm, ano)) return { ok: true };

    const noQuadro = await escolherDataNoQuadro(ano, mes, dia);
    await dormir(200);
    if (dataConfere(valorData(inputDataFreq() || input), br, dd, mm, ano)) return { ok: true };
    if (noQuadro) {
      await dormir(300);
      if (dataConfere(valorData(inputDataFreq() || input), br, dd, mm, ano)) return { ok: true };
    }
    return { ok: false, aviso: `Maestro pediu ${br} e o campo ficou "${valorData(inputDataFreq() || input)}".` };
  }

  function ehBotaoInfo(el) {
    if (!el) return false;
    const t = nrm(`${el.getAttribute("aria-label") || ""} ${el.title || ""} ${el.textContent || ""} ${el.className || ""}`);
    return /info|ajuda|tooltip|pi-info|fa-info/.test(t) || (el.textContent || "").trim() === "i";
  }

  function blocoDoRotulo(rotulo) {
    const alvo = nrm(rotulo);
    const lab = [...document.querySelectorAll("label")].find((l) => {
      if (!visivel(l) || l.closest("#siage-fila-painel")) return false;
      const t = nrm(l.textContent);
      return (t === alvo || t === `${alvo} *`) && !/obrigatorio/.test(t);
    });
    if (!lab) return null;
    return lab.closest(".form-group, app-field, .p-field, .field, .p-formgroup, p-dropdown, p-multiselect, p-select, ng-select") || lab.parentElement;
  }

  function caixaDropdown(bloco) {
    if (!bloco) return null;
    return bloco.querySelector("[role=combobox], .p-multiselect, .p-dropdown, .p-select, .ui-dropdown, .ui-multiselect, ng-select, select") ||
      [...bloco.querySelectorAll("div, span")].find((el) => visivel(el) && /^selecione/.test(nrm(el.textContent)) && nrm(el.textContent).length < 24);
  }

  function setaDropdown(bloco) {
    const caixa = caixaDropdown(bloco);
    const raiz = caixa || bloco;
    const trigger = [...raiz.querySelectorAll(".p-dropdown-trigger, .p-multiselect-trigger, .p-multiselect-dropdown, .p-select-dropdown, .ui-dropdown-trigger, .ng-arrow-wrapper, .p-dropdown-trigger-icon, [class*=chevron], [class*=arrow]")]
      .find((el) => visivel(el) && !ehBotaoInfo(el));
    if (trigger) return trigger;
    if (caixa) return caixa;
    const r = bloco.getBoundingClientRect();
    return [...bloco.querySelectorAll("span, div, button, svg")].filter(visivel).find((el) => {
      if (ehBotaoInfo(el)) return false;
      const b = el.getBoundingClientRect();
      return b.left > r.left + r.width * 0.7 && b.width <= 48 && b.height <= 48;
    });
  }

  function casaOpcaoLista(texto, trecho) {
    const t = nrm(texto);
    if (!t || t.length > 80 || /selecione|obrigatorio/.test(t)) return false;
    const n = String(trecho).match(/\d+/);
    if (!n) return t.includes(nrm(trecho));
    if (/periodo/.test(nrm(trecho)) || /periodo/.test(t)) {
      return new RegExp(`^${n[0]}\\s*(º|°|o)?\\s*periodo`).test(t);
    }
    return new RegExp(`(^|[^0-9])${n[0]}\\s*(º|°|o|a|ª)?(\\s|$|tempo|horario|[^0-9])`).test(t);
  }

  function itensListaAberta() {
    return [...document.querySelectorAll("[role=option], li.p-dropdown-item, li.p-select-option, li.ui-dropdown-item, .ng-option, .p-dropdown-item, .p-multiselect-item, .p-multiselect-option, li.p-multiselect-item, li.ui-multiselect-item, .p-select-option")]
      .filter((el) => visivel(el) && !el.closest("#siage-fila-painel"));
  }

  function textoTempo(s) {
    return nrm(s).replace(/[º°ª]/g, "o");
  }

  function numeroTempoOpcao(texto) {
    const t = textoTempo(texto);
    const m = t.match(/(?:^|[^0-9])(\d{1,2})\s*o?\s*tempo\b/);
    return m ? Number(m[1]) : 0;
  }

  function opcaoTempoVaga(el) {
    return !/p-disabled|ui-state-disabled/.test(el.className || "") && el.getAttribute("aria-disabled") !== "true";
  }

  function rotuloExatoTempo(el) {
    const bruto = (el.innerText || el.textContent || "").replace(/\s+/g, " ").trim();
    if (!bruto || bruto.length > 48) return false;
    if (/^\d{1,2}\D{0,12}Tempo$/i.test(bruto)) return true;
    return /^\d{1,2}\s*o?\s*tempo$/i.test(textoTempo(bruto));
  }

  function tecla(el, key, code, keyCode) {
    if (!el) return;
    const opts = { bubbles: true, cancelable: true, key, code, keyCode, which: keyCode };
    el.dispatchEvent(new KeyboardEvent("keydown", opts));
    el.dispatchEvent(new KeyboardEvent("keyup", opts));
  }

  let painelTempoAberto = null;

  function painelTempos() {
    if (painelTempoAberto && document.body.contains(painelTempoAberto) && visivel(painelTempoAberto)) return painelTempoAberto;
    const porClasse = [...document.querySelectorAll(".p-multiselect-panel, .p-multiselect-overlay, .p-overlaypanel, .ui-multiselect-panel, .p-dropdown-panel, .p-select-overlay")]
      .find((el) => visivel(el) && !el.closest("#siage-fila-painel"));
    if (porClasse) {
      painelTempoAberto = porClasse;
      return porClasse;
    }
    const blocos = [...document.querySelectorAll("div, ul, [role=listbox]")].filter(visivel).filter((p) => {
      if (p.closest("#siage-fila-painel")) return false;
      const r = p.getBoundingClientRect();
      if (r.width < 90 || r.width > 640 || r.height < 40 || r.height > 700) return false;
      const t = textoTempo(p.innerText || "");
      const temItem = /\d{1,2}\s*o?\s*tempo/.test(t);
      const temBusca = [...p.querySelectorAll("input")].some((el) => visivel(el) && el.type !== "checkbox" && el.type !== "hidden");
      const varios = /1\s*o?\s*tempo/.test(t) && /2\s*o?\s*tempo/.test(t);
      return temItem && (varios || temBusca);
    });
    blocos.sort((a, b) => (a.offsetWidth * a.offsetHeight) - (b.offsetWidth * b.offsetHeight));
    painelTempoAberto = blocos[0] || null;
    return painelTempoAberto;
  }

  function filtroDoPainel(painel) {
    return painel && [...painel.querySelectorAll("input")].find((el) => visivel(el) && el.type !== "checkbox" && el.type !== "hidden");
  }

  function areaRolavel(painel) {
    if (!painel) return null;
    return painel.querySelector(".p-multiselect-items-wrapper, .p-dropdown-items-wrapper, .p-scroller, .p-virtualscroller-content, .p-multiselect-list, .p-listbox-list-wrapper, ul") || painel;
  }

  function linhaComCaixa(el) {
    let n = el;
    for (let i = 0; i < 10 && n && n !== document.body; i++) {
      const caixa = n.querySelector && n.querySelector("input[type=checkbox], .p-checkbox, .p-checkbox-box, [role=checkbox]");
      const t = (n.innerText || "").replace(/\s+/g, " ").trim();
      if (caixa && /^\d{1,2}\D{0,8}Tempo$/i.test(t)) return n;
      n = n.parentElement;
    }
    return el.closest("li, [role=option], .p-multiselect-item, .p-multiselect-option") || el.parentElement || el;
  }

  function linhasTempo() {
    const painel = painelTempos();
    const raiz = painel || document;
    const sel = "[role=option], li, .p-multiselect-item, .p-multiselect-option, .p-listbox-option, label, span, div";
    const nos = [...raiz.querySelectorAll(sel)].filter(visivel).filter((el) => {
      if (el.closest("#siage-fila-painel")) return false;
      return rotuloExatoTempo(el);
    });
    const mapa = new Map();
    nos.forEach((el) => {
      const n = numeroTempoOpcao(el.textContent || el.innerText);
      if (!n || n > 12) return;
      const atual = mapa.get(n);
      if (!atual || atual.contains(el) || el.offsetWidth * el.offsetHeight < atual.offsetWidth * atual.offsetHeight) mapa.set(n, el);
    });
    return [...mapa.entries()].map(([n, el]) => {
      const row = linhaComCaixa(el);
      const box = row.querySelector("input[type=checkbox], .p-checkbox-box, [role=checkbox], .p-checkbox");
      return { n, el: row, box, label: el, checked: caixaMarcada(row), disabled: /p-disabled|ui-state-disabled/.test(row.className || "") };
    });
  }

  function linhasPorCheckbox() {
    const painel = painelTempos();
    const raiz = painel || document;
    const boxes = [...raiz.querySelectorAll("input[type=checkbox], .p-checkbox-box, .p-checkbox, [role=checkbox]")].filter((el) => visivel(el) && !el.closest("#siage-fila-painel"));
    const mapa = new Map();
    boxes.forEach((box) => {
      const row = box.closest("li, [role=option], .p-multiselect-item, .p-multiselect-option, label") || box.parentElement;
      const n = numeroTempoOpcao((row && row.innerText) || "");
      if (!n || n > 12 || mapa.has(n)) return;
      mapa.set(n, { n, el: row, box, checked: caixaMarcada(row), disabled: /p-disabled|ui-state-disabled/.test((row && row.className) || "") });
    });
    linhasTempo().forEach((l) => { if (!mapa.has(l.n)) mapa.set(l.n, l); });
    return [...mapa.values()];
  }

  function sairDoFiltro() {
    const painel = painelTempos();
    const filtro = filtroDoPainel(painel);
    const ae = document.activeElement;
    if (ae && ae.tagName === "INPUT" && ae.type !== "checkbox") {
      try { ae.blur(); } catch (e) {}
    }
    if (filtro && filtro !== document.activeElement) return;
    if (filtro) {
      try { filtro.blur(); } catch (e) {}
    }
  }

  async function escreverFiltro(input, texto) {
    if (!input) return;
    clickSo(input);
    input.focus();
    try { input.select(); } catch (e) {}
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(input, texto);
    try { input.dispatchEvent(new InputEvent("input", { bubbles: true, data: texto, inputType: "insertText" })); } catch (e) {
      input.dispatchEvent(new Event("input", { bubbles: true }));
    }
    input.dispatchEvent(new Event("change", { bubbles: true }));
    input.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: texto.slice(-1) || "Backspace" }));
    input.dispatchEvent(new KeyboardEvent("keyup", { bubbles: true, key: texto.slice(-1) || "Backspace" }));
    await dormir(280);
  }

  function caixaMarcada(row) {
    if (!row) return false;
    const input = row.querySelector("input[type=checkbox]");
    if (input) return !!input.checked;
    const box = row.querySelector("[role=checkbox], .p-checkbox-box");
    if (box && box.getAttribute("aria-checked") === "true") return true;
    if (box && /p-checkbox-checked/.test(box.className || "")) return true;
    return false;
  }

  function linhaMarcada(row) {
    return caixaMarcada(row);
  }

  function tempoJaNoCampo(n) {
    const bloco = blocoDoRotulo("tempo");
    const caixa = caixaDropdown(bloco);
    const t = textoTempo(((caixa && caixa.innerText) || (bloco && bloco.innerText) || ""));
    if (/selecione/.test(t) && !new RegExp(`(^|[^0-9])${n}\\s*o?\\s*tempo`).test(t)) return false;
    return new RegExp(`(^|[^0-9])${n}\\s*o?\\s*tempo`).test(t);
  }

  function cliqueSimples(el) {
    if (!el || typeof el.click !== "function") return false;
    el.click();
    return true;
  }

  function linhaAzul(row) {
    if (!row) return false;
    const cls = `${row.className || ""} ${row.getAttribute("class") || ""}`;
    if (/p-highlight|p-focus|ui-state-highlight|p-checkbox-checked/.test(cls)) return true;
    const box = row.querySelector(".p-checkbox-box, .p-checkbox, [role=option], [role=checkbox]");
    if (box && /p-highlight|p-checkbox-checked/.test(box.className || "")) return true;
    if (row.getAttribute("aria-selected") === "true") return true;
    try {
      const m = (getComputedStyle(row).backgroundColor || "").match(/\d+/g);
      if (m && m.length >= 3) {
        const r = +m[0], g = +m[1], b = +m[2];
        if (b > 130 && b > r + 15 && b >= g) return true;
      }
    } catch (e) {}
    return caixaMarcada(row);
  }

  function tempoGravado(n) {
    return tempoJaNoCampo(n);
  }

  function alvoForaDoTempo() {
    const nos = [...document.querySelectorAll("h1, h2, h3, h4, h5, legend, label, p, strong, span")];
    return nos.find((el) => {
      if (!visivel(el) || el.closest("#siage-fila-painel") || el.closest(".p-multiselect-panel, .p-overlaypanel, .p-dropdown-panel")) return false;
      const t = nrm(el.textContent);
      return t === "informacoes sobre a aula" || t === "buscar por" || /^buscar por/.test(t);
    }) || nos.find((el) => visivel(el) && nrm(el.textContent) === "estudante");
  }

  async function clicarForaDoTempo() {
    const fora = alvoForaDoTempo();
    if (fora) cliqueSimples(fora);
    await dormir(700);
    recusarCancelar();
  }

  async function abrirPainelTempo() {
    painelTempoAberto = null;
    if (linhasPorCheckbox().length || linhasTempo().length) return painelTempos() || document.body;
    const bloco = blocoDoRotulo("tempo");
    const alvo = setaDropdown(bloco) || caixaDropdown(bloco);
    if (alvo) cliqueSimples(alvo);
    for (let i = 0; i < 30; i++) {
      painelTempoAberto = null;
      if (linhasPorCheckbox().length || linhasTempo().length) return painelTempos() || document.body;
      if (painelTempos()) return painelTempos();
      await dormir(150);
    }
    return painelTempos() || (linhasTempo().length ? document.body : null);
  }

  async function revelarTempo(n) {
    const painel = await abrirPainelTempo();
    if (!painel) return null;
    await dormir(500);
    let hit = linhasPorCheckbox().find((l) => l.n === n) || linhasTempo().find((l) => l.n === n);
    if (hit) {
      try { (hit.label || hit.el).scrollIntoView({ block: "nearest" }); } catch (e) {}
      await dormir(300);
      return hit;
    }
    const wrap = areaRolavel(painel);
    if (wrap) wrap.scrollTop = 0;
    for (let i = 0; i < 16; i++) {
      hit = linhasPorCheckbox().find((l) => l.n === n) || linhasTempo().find((l) => l.n === n);
      if (hit) {
        try { (hit.label || hit.el).scrollIntoView({ block: "nearest" }); } catch (e) {}
        await dormir(300);
        return hit;
      }
      if (wrap) wrap.scrollTop += Math.max(32, Math.floor((wrap.clientHeight || 80) * 0.55));
      await dormir(120);
    }
    return null;
  }

  function temposNoCampo() {
    const bloco = blocoDoRotulo("tempo");
    const caixa = caixaDropdown(bloco);
    const t = textoTempo(((caixa && caixa.innerText) || (bloco && bloco.innerText) || ""));
    if (/selecione/.test(t) && !/\d+\s*o?\s*tempo/.test(t)) return [];
    const found = [];
    const re = /(\d{1,2})\s*o?\s*tempo/g;
    let m;
    while ((m = re.exec(t))) found.push(Number(m[1]));
    return [...new Set(found)];
  }

  function acharLinhaTempo(n) {
    return linhasPorCheckbox().find((l) => l.n === n) || linhasTempo().find((l) => l.n === n) || null;
  }

  async function marcarLinhaTempoUmaVez(n) {
    let hit = acharLinhaTempo(n);
    if (!hit) {
      const wrap = areaRolavel(painelTempos());
      if (wrap) {
        wrap.scrollTop = 0;
        for (let i = 0; i < 16 && !hit; i++) {
          wrap.scrollTop += Math.max(32, Math.floor((wrap.clientHeight || 80) * 0.5));
          await dormir(120);
          hit = acharLinhaTempo(n);
        }
      }
    }
    if (!hit || hit.disabled) return null;
    if (linhaAzul(hit.el) || caixaMarcada(hit.el)) return hit;
    cliqueSimples(hit.label || hit.el);
    const fim = Date.now() + 2000;
    while (Date.now() < fim) {
      if (linhaAzul(hit.el) || caixaMarcada(hit.el)) return hit;
      await dormir(150);
    }
    return (linhaAzul(hit.el) || caixaMarcada(hit.el)) ? hit : null;
  }

  async function marcarTemposLista(ns, permitirSubstituto) {
    recusarCancelar();
    ns = [...new Set((ns || []).map(Number).filter((n) => n > 0 && n <= 12))];
    if (!ns.length) return { ok: false, aviso: "Tempo inválido." };
    if (dataAindaVazia()) return { ok: false, aviso: "A data ainda está vazia; o Tempo não carrega sem ela.", motivo: "sem-data" };
    if (periodoAindaVazio()) return { ok: false, aviso: "O período ainda está em Selecione; o Tempo não carrega sem ele.", motivo: "sem-periodo" };
    const ja = temposNoCampo();
    if (ns.every((n) => ja.includes(n))) return { ok: true, escolhidos: ns, substituto: false };

    await revelarTempo(ns[0]);
    await dormir(450);
    if (!acharLinhaTempo(ns[0]) && !linhasTempo().length && !linhasPorCheckbox().length) {
      return { ok: false, aviso: "A lista de Tempo não abriu.", motivo: "lista-vazia" };
    }

    const marcados = [];
    const faltou = [];
    for (const n of ns) {
      const hit = await marcarLinhaTempoUmaVez(n);
      if (hit) marcados.push(n);
      else faltou.push(n);
      await dormir(350);
    }

    if (permitirSubstituto && faltou.length) {
      const usados = new Set(marcados);
      for (const n of [...faltou]) {
        const livres = linhasPorCheckbox().concat(linhasTempo())
          .filter((l) => !l.disabled && !usados.has(l.n) && !linhaAzul(l.el) && !caixaMarcada(l.el));
        livres.sort((a, b) => Math.abs(a.n - n) - Math.abs(b.n - n) || a.n - b.n);
        if (!livres[0]) continue;
        cliqueSimples(livres[0].label || livres[0].el);
        await dormir(400);
        usados.add(livres[0].n);
        marcados.push(livres[0].n);
        faltou.splice(faltou.indexOf(n), 1);
      }
    }

    await dormir(400);
    await clicarForaDoTempo();
    const gravados = temposNoCampo();
    if (gravados.length) {
      return {
        ok: true,
        escolhidos: gravados,
        escolhido: gravados[0],
        substituto: !ns.every((n) => gravados.includes(n))
      };
    }
    return { ok: false, aviso: "Cliquei o tempo, mas o campo continua em Selecione." };
  }

  async function marcarTempoPedido(n, permitirSubstituto) {
    const r = await marcarTemposLista([n], permitirSubstituto);
    if (r && r.escolhidos && r.escolhidos.length) r.escolhido = r.escolhidos[0];
    return r;
  }

  function dataAindaVazia() {
    const input = inputDataFreq();
    return !input || !/\d{2}\/\d{2}/.test((input.value || "").replace(/\s/g, ""));
  }

  function periodoAindaVazio() {
    const bloco = blocoDoRotulo("periodo");
    if (!bloco) return true;
    const t = nrm(bloco.innerText || "");
    return /selecione/.test(t) && !/\d+\s*(º|°|o)?\s*periodo/.test(t);
  }

  async function escolherListaFreq(rotulo, trecho) {
    recusarCancelar();
    const nome = nrm(rotulo);
    if (nome === "tempo") {
      if (dataAindaVazia()) return { ok: false, aviso: "A data ainda está vazia; o Tempo não carrega sem ela.", motivo: "sem-data" };
      if (periodoAindaVazio()) return { ok: false, aviso: "O período ainda está em Selecione; o Tempo não carrega sem ele.", motivo: "sem-periodo" };
    }

    const bloco = blocoDoRotulo(rotulo);
    if (!bloco) return { ok: false, aviso: `Não achei o campo ${rotulo}.`, motivo: "sem-campo" };

    for (let i = 0; i < 15; i++) {
      const caixa = caixaDropdown(bloco);
      const off = caixa && (/p-disabled|disabled/.test(caixa.className) || caixa.getAttribute("aria-disabled") === "true");
      if (!off) break;
      await dormir(200);
    }

    const seta = setaDropdown(bloco);
    if (!seta) return { ok: false, aviso: `Não achei a seta de ${rotulo}.`, motivo: "sem-seta" };
    clickSo(seta);
    const r = seta.getBoundingClientRect();
    clickPonto(r.right - 8, r.top + r.height / 2);

    let item = null;
    let itens = [];
    for (let i = 0; i < 20; i++) {
      recusarCancelar();
      itens = itensListaAberta();
      item = itens.find((el) => casaOpcaoLista(el.textContent, trecho));
      if (item) break;
      await dormir(200);
    }
    let substituto = 0;
    if (!item && nome === "tempo") {
      recusarCancelar();
      clickSo(seta);
      for (let i = 0; i < 12 && !item; i++) {
        itens = itensListaAberta();
        item = itens.find((el) => casaOpcaoLista(el.textContent, trecho) && opcaoTempoVaga(el));
        if (item) break;
        await dormir(200);
      }
      if (!item) {
        const pedido = Number(String(trecho).match(/\d+/) || [0]);
        const livres = itens.filter(opcaoTempoVaga)
          .map((el) => ({ el, n: numeroTempoOpcao(el.textContent) }))
          .filter((x) => x.n > 0)
          .sort((a, b) => Math.abs(a.n - pedido) - Math.abs(b.n - pedido) || a.n - b.n);
        if (livres[0]) {
          item = livres[0].el;
          substituto = livres[0].n;
        }
      }
    }
    if (!item) {
      if (!itens.length) {
        return { ok: false, aviso: `A lista de ${rotulo} não abriu.`, motivo: "lista-vazia" };
      }
      return {
        ok: false,
        aviso: `O tempo ${trecho} não está na lista do SIAGE. Se essa aula já foi lançada, está no portal.`,
        motivo: "opcao-ausente"
      };
    }
    const caixa = item.querySelector(".p-checkbox-box, .p-checkbox, input[type=checkbox]");
    clickSo(caixa || item);
    await dormir(350);
    recusarCancelar();
    return { ok: true, escolhido: substituto || Number(String(trecho).match(/\d+/) || [0]), substituto: !!substituto };
  }

  window.addEventListener("message", (ev) => {
    if (ev.source !== window || !ev.data || ev.data.__siage !== 1) return;
    const d = ev.data;
    if (d.acao === "click") clickPonto(d.x, d.y);
    if (d.acao === "type" && d.texto) {
      const el = document.activeElement;
      if (!el) return;
      el.focus();
      try { document.execCommand("selectAll", false, null); } catch (e) {}
      try { document.execCommand("insertText", false, d.texto); } catch (e) {}
    }
    if (d.acao === "enter") {
      const el = document.activeElement || document.body;
      const opts = { bubbles: true, cancelable: true, key: "Enter", code: "Enter", keyCode: 13, which: 13 };
      el.dispatchEvent(new KeyboardEvent("keydown", opts));
      el.dispatchEvent(new KeyboardEvent("keyup", opts));
    }
    if (d.acao === "fecharAlerta") {
      const ok = fecharAlerta();
      window.postMessage({ __siage: 2, acao: "fecharAlerta:ok", ok }, "*");
    }
    if (d.acao === "escolherMes" && d.tela) {
      escolherMesNaPagina(d.tela).then((ok) => {
        window.postMessage({ __siage: 2, acao: "escolherMes:ok", ok: !!ok }, "*");
      });
    }
    if (d.acao === "dataFreq" && (d.iso || d.data_br)) {
      preencherDataFreq(d.iso, d.data_br).then((r) => {
        window.postMessage({ __siage: 2, acao: "dataFreq:ok", ok: !!(r && r.ok), aviso: (r && r.aviso) || "" }, "*");
      });
    }
    if (d.acao === "listaFreq" && d.rotulo && d.trecho) {
      const p = nrm(d.rotulo) === "tempo"
        ? marcarTempoPedido(d.trecho, true)
        : escolherListaFreq(d.rotulo, d.trecho);
      p.then((r) => {
        window.postMessage({ __siage: 2, acao: "listaFreq:ok", ok: !!(r && r.ok), aviso: (r && r.aviso) || "", motivo: (r && r.motivo) || "", escolhido: (r && r.escolhido) || "", substituto: !!(r && r.substituto) }, "*");
      });
    }
    if (d.acao === "marcarTempo" && d.n) {
      marcarTempoPedido(d.n, d.substituto !== false).then((r) => {
        window.postMessage({ __siage: 2, acao: "marcarTempo:ok", ok: !!(r && r.ok), aviso: (r && r.aviso) || "", motivo: (r && r.motivo) || "", escolhido: (r && r.escolhido) || "", escolhidos: (r && r.escolhidos) || [], substituto: !!(r && r.substituto) }, "*");
      });
    }
    if (d.acao === "marcarTempos") {
      const ns = Array.isArray(d.ns) ? d.ns : (d.n ? [d.n] : []);
      marcarTemposLista(ns, d.substituto !== false).then((r) => {
        window.postMessage({ __siage: 2, acao: "marcarTempos:ok", ok: !!(r && r.ok), aviso: (r && r.aviso) || "", motivo: (r && r.motivo) || "", escolhido: (r && r.escolhido) || "", escolhidos: (r && r.escolhidos) || [], substituto: !!(r && r.substituto) }, "*");
      });
    }
  });
})();
