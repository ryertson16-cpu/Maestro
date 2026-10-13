(() => {
  if (window.__siageNotas) return;
  window.__siageNotas = true;

  const norm = (s) => String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");
  const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
  const visivel = (el) => !!el && !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  const q = (sel, raiz = document) => [...raiz.querySelectorAll(sel)];
  const pageText = () => (document.body?.innerText || "").slice(0, 4000);

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

  async function clicarConfirmacao() {
    await esperar(400);
    const sim = botaoPorTexto(/^(sim|confirmar|ok|lancar)$/);
    if (sim) sim.click();
  }

  async function salvarNoSiage(modo) {
    const botao = modo === "launch"
      ? botaoPorTexto(/lancar notas/)
      : botaoPorTexto(/salvar parcialmente/);
    if (!botao) return { ok: false, msg: modo === "launch" ? "não achei Lançar notas" : "não achei Salvar parcialmente" };
    botao.click();
    await clicarConfirmacao();
    await esperar(800);
    return { ok: true };
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

    const salvo = await salvarNoSiage(modo);
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
})();
