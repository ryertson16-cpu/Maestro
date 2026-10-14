(() => {
  if (window.__siageNotas) return;
  window.__siageNotas = true;

  const norm = (s) => String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");
  const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
  const visivel = (el) => !!el && !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  const q = (sel, raiz = document) => [...raiz.querySelectorAll(sel)];
  const pageText = () => (document.body?.innerText || "").slice(0, 4000);
  async function aguardar(fn, ms = 8000) {
    const fim = Date.now() + ms;
    while (Date.now() < fim) { const r = fn(); if (r) return r; await esperar(150); }
    return null;
  }

  function ehTelaDeNotas() {
    const t = pageText();
    return /1[ªa]\s*unidade/i.test(t) && /rec\s*\/?\s*rep/i.test(t);
  }

  function tokens(nome) {
    return norm(nome).split(" ").filter((p) => p.length > 1);
  }

  function pontuacaoNome(siage, maestro) {
    const a = norm(siage);
    const b = norm(maestro);
    if (!a || !b) return 0;
    if (a === b) return 100;
    if (a.startsWith(b) || b.startsWith(a)) return 50;
    return tokens(maestro).filter((p) => tokens(siage).includes(p)).length;
  }

  function nomeDaLinha(row, input) {
    const cells = q("td", row);
    const nome = cells.find((td) => input && !td.contains(input)) || cells[0] || row;
    return ((nome.innerText || "").trim().split("\n")[0] || "").trim();
  }

  function linhasDeNotas() {
    const items = [];
    q("table tbody tr, table tr, [class*='p-datatable-row']").forEach((row) => {
      const inputs = q("input", row).filter((input) =>
        input.type !== "hidden" &&
        input.type !== "checkbox" &&
        input.type !== "search" &&
        visivel(input)
      );
      const nome = nomeDaLinha(row, inputs[0]);
      if (!nome || inputs.length < 2) return;
      if (norm(nome) === "estudantes" || /unidade/.test(norm(nome))) return;
      items.push({ row, nome, inputs });
    });
    return items;
  }

  function acharAluno(items, nome) {
    let melhor = null;
    let pontos = 0;
    items.forEach((item) => {
      const n = pontuacaoNome(item.nome, nome);
      if (n > pontos) { melhor = item; pontos = n; }
    });
    return pontos >= 2 ? melhor : null;
  }

  function formatarNota(valor) {
    const n = Number(valor);
    if (!Number.isFinite(n)) return "";
    return n.toFixed(1).replace(".", ",");
  }

  function preencherCampo(campo, valor) {
    if (!campo || campo.disabled || campo.readOnly) return false;
    if (valor == null || valor === "") return false;
    const texto = formatarNota(valor);
    if (!texto) return false;
    campo.focus();
    campo.value = texto;
    campo.dispatchEvent(new Event("input", { bubbles: true }));
    campo.dispatchEvent(new Event("change", { bubbles: true }));
    campo.blur();
    return true;
  }

  function valoresDaUnidade(aluno, numero) {
    const unidade = (aluno.units || []).find((u) => u.number === numero) || {};
    return [unidade.score, unidade.recovery];
  }

  function preencherNotas(alunos) {
    const linhas = linhasDeNotas();
    let preenchidos = 0;
    const faltando = [];
    const travados = [];

    alunos.forEach((aluno) => {
      const match = acharAluno(linhas, aluno.name || aluno.name_key);
      if (!match) {
        faltando.push(aluno.name);
        return;
      }
      const editaveis = match.inputs.filter((input) => !input.disabled && !input.readOnly);
      if (!editaveis.length) {
        travados.push(aluno.name);
        return;
      }
      const valores = [
        ...valoresDaUnidade(aluno, 1),
        ...valoresDaUnidade(aluno, 2),
        ...valoresDaUnidade(aluno, 3)
      ];
      valores.forEach((valor, i) => {
        if (i < editaveis.length) preencherCampo(editaveis[i], valor);
      });
      preenchidos += 1;
    });

    return { preenchidos, faltando, travados, totalLinhas: linhas.length };
  }

  function botaoPorTexto(re) {
    return q("button, input[type=submit], [role=button], a.btn").filter(visivel).find((b) => {
      if (b.disabled) return false;
      const t = norm(b.innerText || b.value || b.textContent);
      return re.test(t);
    });
  }

  function avisoNaTela() {
    return q(".swal2-popup .swal2-title, .swal2-popup .swal2-html-container, .toast-message, .toast-body, .ui-toast-detail, .ui-toast-summary, .p-toast-detail")
      .filter(visivel).map((e) => e.textContent.trim()).filter(Boolean).join(" ").slice(0, 160);
  }

  function mensagemDoSistema() {
    const m = q(".toast-message, .toast-body, .ui-toast-detail, .ui-toast-summary, .p-toast-detail, .swal2-html-container, .swal2-title, .alert, .invalid-feedback, .ui-message-error")
      .filter(visivel).map((e) => e.textContent.trim()).filter(Boolean);
    return m.join(" ").slice(0, 160);
  }

  function tipoDoAviso(texto) {
    const t = norm(texto);
    if ((/senha/.test(t) && /incorret|invalid|errad|nao confere|nao corresponde/.test(t)) || /credenc/.test(t)) return "senha";
    if (/sucesso|salv[oa] com|lancad[oa] com|registrad[oa] com|realizad[oa] com/.test(t)) return "sucesso";
    if (/deseja|tem certeza|confirma/.test(t)) return "pergunta";
    if (t) return "falha";
    return "";
  }

  function campoSenhaVisivel() {
    return q("input[type=password]").find(visivel);
  }

  function preencherSenha(campo, senha) {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(campo, senha);
    for (const tipo of ["input", "keyup", "change", "blur"]) {
      campo.dispatchEvent(new Event(tipo, { bubbles: true }));
    }
  }

  function confirmarCaixaDaSenha(campo) {
    let caixa = campo.closest(".modal-content, .modal, .ui-dialog, .p-dialog, .swal2-popup, [role=dialog], mat-dialog-container");
    if (!caixa) {
      caixa = campo;
      for (let k = 0; k < 6 && caixa.parentElement; k++) {
        caixa = caixa.parentElement;
        if (q("button", caixa).length) break;
      }
    }
    const ok = q("button, input[type=submit], .swal2-confirm", caixa)
      .filter((b) => visivel(b) && !b.disabled)
      .find((b) => /^(confirmar|salvar|ok|enviar|assinar|registrar|continuar|sim|lancar)$/.test(norm(b.textContent || b.value)));
    if (ok) ok.click();
    else campo.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter", keyCode: 13 }));
  }

  function camposTravados() {
    const linhas = linhasDeNotas();
    return linhas.length > 0 && linhas.every((item) => item.inputs.every((input) => input.disabled || input.readOnly));
  }

  async function lerSenha(fallback) {
    if (fallback) return fallback;
    try { return (await chrome.storage.session.get("senha")).senha || ""; } catch (e) { return ""; }
  }

  async function confirmarComSenha(senha) {
    const fim = Date.now() + 180000;
    let senhaEnviada = false;

    while (Date.now() < fim) {
      const aviso = avisoNaTela();
      if (aviso) {
        const tipo = tipoDoAviso(aviso);
        if (tipo === "senha") return { ok: false, msg: "senha não aceita: " + aviso };
        if (tipo === "pergunta") {
          const sim = q(".swal2-confirm, .p-confirm-dialog-accept, .modal.show .btn-primary").find(visivel)
            || botaoPorTexto(/^(sim|confirmar|ok|lancar)$/);
          if (sim) sim.click();
          await esperar(500);
          continue;
        }
        if (tipo === "sucesso") return { ok: true };
        if (tipo === "falha") return { ok: false, msg: "o SIAGE respondeu: " + aviso };
      }

      const campoSenha = campoSenhaVisivel();
      if (campoSenha) {
        if (!senha) return { ok: false, msg: "o SIAGE pediu a senha; digite-a na extensão (campo Senha do SIAGE)" };
        if (tipoDoAviso(mensagemDoSistema()) === "senha") {
          return { ok: false, msg: "senha não aceita: " + mensagemDoSistema() };
        }
        if (!senhaEnviada || campoSenha.value !== senha) {
          preencherSenha(campoSenha, senha);
          await esperar(300);
          confirmarCaixaDaSenha(campoSenha);
          senhaEnviada = true;
          await esperar(800);
        }
        continue;
      }

      if (senhaEnviada && camposTravados()) return { ok: true };
      await esperar(400);
    }

    if (senhaEnviada) return { ok: true };
    return { ok: false, msg: "o SIAGE não pediu a senha nem confirmou o lançamento" };
  }

  async function salvarNoSiage(modo, senha) {
    const botao = modo === "launch"
      ? botaoPorTexto(/lancar notas/)
      : botaoPorTexto(/salvar parcialmente/);
    if (!botao) return { ok: false, msg: modo === "launch" ? "não achei Lançar notas" : "não achei Salvar parcialmente" };
    botao.click();
    return confirmarComSenha(senha);
  }

  function avisarMaestro(payload, status, message) {
    try {
      chrome.runtime.sendMessage({
        tipo: "maestro-ledger",
        kind: "grades",
        classroomId: payload.classroom && payload.classroom.id,
        bimester: payload.bimester,
        status,
        message: message || "",
        token: payload.token || "",
        origin: payload.origin || ""
      }, () => void chrome.runtime.lastError);
    } catch (e) {}
  }

  async function trabalharNotas(msg) {
    const payload = msg.payload || {};
    const modo = msg.saveMode === "launch" ? "launch" : "partial";
    const alunos = payload.grades || [];
    if (!ehTelaDeNotas()) {
      return { ok: false, msg: "Abra a tela de notas da turma no SIAGE (1ª, 2ª e 3ª unidade)." };
    }
    if (!alunos.length) return { ok: false, msg: "Este JSON não tem notas." };

    const r = preencherNotas(alunos);
    if (!r.preenchidos && r.travados.length) {
      avisarMaestro(payload, "launched", "a tela já estava lançada (campos travados)");
      return { ok: true, status: "launched", msg: "Esta tela já está lançada no SIAGE. Não dá para alterar." };
    }
    if (!r.preenchidos) {
      avisarMaestro(payload, "failed", "nenhum aluno casou com a lista do SIAGE");
      return { ok: false, msg: "Não casei os nomes dos alunos com a lista do SIAGE." };
    }

    const senha = await lerSenha(msg.senha);
    if (modo === "launch" && !senha) {
      avisarMaestro(payload, "failed", "falta a senha do SIAGE");
      return { ok: false, msg: "Digite a senha do SIAGE na extensão para lançar as notas." };
    }

    const salvo = await salvarNoSiage(modo, senha);
    if (!salvo.ok) {
      avisarMaestro(payload, "failed", salvo.msg);
      return { ok: false, msg: `Notas preenchidas, mas ${salvo.msg}. Confira no portal.` };
    }

    const status = modo === "launch" ? "launched" : "partial";
    let message = `${r.preenchidos} aluno(s) · ${modo === "launch" ? "lançado" : "salvo parcialmente"}`;
    if (r.faltando.length) message += ` · não achei: ${r.faltando.slice(0, 3).join(", ")}`;
    avisarMaestro(payload, status, message);
    return { ok: true, status, msg: message };
  }

  chrome.runtime.onMessage.addListener((msg, _s, responder) => {
    if (msg && msg.tipo === "ping-notas") { responder({ ok: true }); return; }
    if (msg && msg.tipo === "iniciar-notas") {
      trabalharNotas(msg).then(responder).catch((e) => responder({ ok: false, msg: e.message }));
      return true;
    }
  });

  function casarPayloadNotas(lista) {
    const t = norm(pageText());
    return (lista || []).find((payload) => {
      const nome = payload && payload.classroom && payload.classroom.name;
      if (!nome) return false;
      const n = norm(nome);
      if (t.includes(n)) return true;
      const m = n.match(/(\d+)\s*([a-z])\b/) || n.match(/(\d+)\s*(?:serie)?\s*([a-z])\b/);
      if (!m) return false;
      return new RegExp(`(^|[^0-9])${m[1]}\\s*(?:serie\\s*)?${m[2]}([^a-z]|$)`).test(t);
    }) || ((lista || []).length === 1 ? lista[0] : null);
  }

  setTimeout(async () => {
    if (!ehTelaDeNotas() || window.__siageNotasAuto) return;
    let handoff = null;
    try { handoff = (await chrome.storage.local.get("handoff")).handoff; } catch (e) { return; }
    const payload = casarPayloadNotas(handoff && handoff.grades);
    if (!payload) return;
    window.__siageNotasAuto = true;
    let senha = "";
    try { senha = (await chrome.storage.session.get("senha")).senha || ""; } catch (e) {}
    trabalharNotas({ payload, saveMode: "partial", senha }).catch(() => {});
  }, 1800);
})();
