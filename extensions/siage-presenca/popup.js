const $ = (id) => document.getElementById(id);
const norm = (s) => (s || "").toString().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/\s+/g, " ").trim().toLowerCase();
const dataBR = (iso) => iso.split("-").reverse().join("/");

// Períodos 2026: datas da tabela "Dias Letivos por Período" do SIAGE (é o que o sistema usa).
// O 4º vai até 23/12 porque o calendário oficial da rede termina as aulas em 22/12 e o SIAGE mostra 17/12.
const PERIODOS = [
  { n: 1, ini: "2026-02-10", fim: "2026-04-23" },
  { n: 2, ini: "2026-04-24", fim: "2026-07-23" },
  { n: 3, ini: "2026-07-24", fim: "2026-10-05" },
  { n: 4, ini: "2026-10-06", fim: "2026-12-23" },
];
const periodoPelaData = (iso) => (PERIODOS.find((x) => iso >= x.ini && iso <= x.fim) || {}).n || null;

let linhasDoArquivo = null; // linhas lidas da planilha escolhida (tem prioridade sobre o texto colado)

function lerData(v) {
  if (v instanceof Date) return `${v.getFullYear()}-${String(v.getMonth() + 1).padStart(2, "0")}-${String(v.getDate()).padStart(2, "0")}`;
  const s = String(v || "").trim();
  let m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = s.match(/(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{2,4})/);
  if (!m) return null;
  let [, d, mo, a] = m;
  if (a.length === 2) a = "20" + a;
  const dt = new Date(+a, +mo - 1, +d);
  if (dt.getMonth() !== +mo - 1) return null;
  return `${a}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
}

function detectarSeparador(texto) {
  const primeira = (texto.split(/\n/).find((l) => l.trim()) || "");
  const semAspas = primeira.replace(/"[^"]*"/g, "");
  const tabs = (semAspas.match(/\t/g) || []).length;
  if (tabs >= 2) return "\t";
  const virgulas = (semAspas.match(/,/g) || []).length;
  const pontos = (semAspas.match(/;/g) || []).length;
  return pontos > virgulas ? ";" : ",";
}

function linhasDaPlanilha(texto) {
  texto = String(texto || "").replace(/^\uFEFF/, "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  const sep = detectarSeparador(texto);
  const linhas = [];
  let row = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < texto.length; i++) {
    const ch = texto[i];
    if (quoted) {
      if (ch === '"') {
        if (texto[i + 1] === '"') { cur += '"'; i += 1; }
        else quoted = false;
      } else cur += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === sep) { row.push(cur); cur = ""; }
    else if (ch === "\n") { row.push(cur); linhas.push(row); row = []; cur = ""; }
    else cur += ch;
  }
  if (cur.length || row.length) { row.push(cur); linhas.push(row); }
  return linhas
    .map((r) => r.map((c) => String(c ?? "").trim()))
    .filter((r) => r.some((c) => c))
    .map((r) => {
      if (r.length === 1 && /[,;\t]/.test(r[0])) {
        const outro = detectarSeparador(r[0] + "\n");
        const partes = [];
        let cell = "";
        let q = false;
        const s = r[0];
        for (let i = 0; i < s.length; i++) {
          const ch = s[i];
          if (q) {
            if (ch === '"') {
              if (s[i + 1] === '"') { cell += '"'; i += 1; }
              else q = false;
            } else cell += ch;
          } else if (ch === '"') q = true;
          else if (ch === outro) { partes.push(cell.trim()); cell = ""; }
          else cell += ch;
        }
        partes.push(cell.trim());
        return partes.length > 1 ? partes : r;
      }
      return r;
    });
}

function ehCabecalho(celulas) {
  const t = (celulas || []).map(norm).join(" ");
  return /\bdata\b/.test(t) && /tempo/.test(t);
}

// Recebe linhas (arrays de células) e monta os grupos turma+componente
function montarGrupos(linhas) {
  const erros = [];
  let col = { data: 0, tempos: 1, turma: 2, componente: 3, faltas: 4, justificados: 5, atrasados: -1, id: -1, token: -1, origin: -1 };
  let inicio = 0;
  const primeira = linhas[0] || [];
  if (ehCabecalho(primeira) || primeira.map(norm).some((c) => c === "data")) {
    const cab = primeira.map(norm);
    const achar = (re) => cab.findIndex((c) => re.test(c));
    col = {
      data: achar(/^data$/),
      tempos: achar(/^tempo/),
      turma: achar(/^turma/),
      componente: achar(/^(componente|disciplina)/),
      faltas: achar(/^faltas?$/),
      justificados: achar(/^justific/),
      atrasados: achar(/^atras/),
      id: achar(/^id/),
      token: achar(/^token/),
      origin: achar(/^maestro$/)
    };
    if (col.data < 0) col.data = 0;
    if (col.tempos < 0) col.tempos = 1;
    inicio = 1;
  }
  let token = "";
  let origin = "";
  const grupos = new Map();
  for (let i = inicio; i < linhas.length; i++) {
    const l = linhas[i] || [];
    if (!l.some((c) => String(c ?? "").trim())) continue;
    const data = lerData(l[col.data]);
    if (!data) { erros.push(`Linha ${i + 1}: data não reconhecida`); continue; }
    if (($("de").value && data < $("de").value) || ($("ate").value && data > $("ate").value)) continue;
    const tempos = (String(l[col.tempos] ?? "").match(/\d+/g) || []).filter((t) => +t > 0 && +t < 20);
    if (!tempos.length) { erros.push(`Linha ${i + 1}: falta o tempo`); continue; }
    const turma = col.turma >= 0 ? String(l[col.turma] ?? "").trim() || null : null;
    const componente = col.componente >= 0 ? String(l[col.componente] ?? "").trim() || null : null;
    const faltas = col.faltas >= 0 ? nomesDaCelula(l[col.faltas]) : [];
    const justificados = col.justificados >= 0 ? nomesDaCelula(l[col.justificados]) : [];
    const atrasados = col.atrasados >= 0 ? nomesDaCelula(l[col.atrasados]) : [];
    const maestroId = col.id >= 0 ? String(l[col.id] ?? "").trim() : "";
    const rowToken = col.token >= 0 ? String(l[col.token] ?? "").trim() : "";
    const rowOrigin = col.origin >= 0 ? String(l[col.origin] ?? "").trim() : "";
    if (rowToken && !token) token = rowToken;
    if (rowOrigin && !origin) origin = rowOrigin;
    const chave = norm(turma) + "|" + norm(componente);
    if (!grupos.has(chave)) grupos.set(chave, { turma, componente, turmaId: null, aulas: [], porData: new Map() });
    const g = grupos.get(chave);
    if (g.porData.has(data)) {
      const a = g.porData.get(data);
      tempos.forEach((t) => { if (!a.tempos.includes(t)) a.tempos.push(t); });
      a.faltas = unirNomes(a.faltas, faltas);
      a.justificados = unirNomes(a.justificados, justificados);
      a.atrasados = unirNomes(a.atrasados, atrasados);
      if (maestroId && !(a.maestroIds || []).includes(maestroId)) a.maestroIds.push(maestroId);
    } else {
      const a = {
        data,
        data_br: data.split("-").reverse().join("/"),
        tempos,
        faltas,
        justificados,
        atrasados,
        maestroIds: maestroId ? [maestroId] : [],
        estado: "pendente",
        msg: ""
      };
      g.porData.set(data, a);
      g.aulas.push(a);
    }
  }
  const escolhido = $("periodo").value;
  const lista = [...grupos.values()].filter((g) => g.aulas.length).map(({ porData, ...g }) => {
    g.aulas.sort((a, b) => a.data.localeCompare(b.data));
    g.aulas.forEach((a) => {
      a.periodo = escolhido === "auto" ? periodoPelaData(a.data) : +escolhido;
      a.periodo_label = a.periodo ? `${a.periodo}º Período` : "";
      a.data_br = a.data_br || a.data.split("-").reverse().join("/");
    });
    return g;
  });
  return { grupos: lista, erros, token, origin };
}

function nomesDaCelula(v) {
  return String(v ?? "").split(/[;\n|]/).map((s) => s.trim()).filter(Boolean);
}
function unirNomes(a, b) {
  const visto = new Set((a || []).map(norm));
  const out = [...(a || [])];
  (b || []).forEach((n) => {
    const k = norm(n);
    if (k && !visto.has(k)) { visto.add(k); out.push(n); }
  });
  return out;
}

function linhasDoTexto(texto) {
  return linhasDaPlanilha(texto);
}

function mesclarPlanilhas(blocos) {
  const out = [];
  let viuCabecalho = false;
  blocos.forEach((linhas) => {
    if (!linhas || !linhas.length) return;
    const primeira = linhas[0] || [];
    const temCab = ehCabecalho(primeira) || primeira.map(norm).some((c) => c === "data");
    if (temCab) {
      if (!viuCabecalho) {
        out.push(primeira);
        viuCabecalho = true;
      }
      out.push(...linhas.slice(1));
    } else {
      out.push(...linhas);
    }
  });
  return out;
}

async function linhasDoArquivoEscolhido(f) {
  const buf = await f.arrayBuffer();
  if (/\.(csv|txt|tsv)$/i.test(f.name)) {
    let texto;
    try { texto = new TextDecoder("utf-8", { fatal: true }).decode(buf); } catch (e) { texto = new TextDecoder("windows-1252").decode(buf); }
    return linhasDaPlanilha(texto);
  }
  const wb = XLSX.read(buf, { type: "array", cellDates: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  return XLSX.utils.sheet_to_json(ws, { header: 1, raw: false, dateNF: "dd/mm/yyyy", defval: "" });
}

function atual() {
  if (linhasDoArquivo) return montarGrupos(linhasDoArquivo);
  return montarGrupos(linhasDoTexto($("lista").value));
}

function atualizarPrevia() {
  const { grupos, erros, token, origin } = atual();
  const el = $("previa");
  el.innerHTML = "";
  const total = grupos.reduce((n, g) => n + g.aulas.length, 0);
  if (total) {
    el.append(`${total} aula(s) em ${grupos.length} turma(s):\n` + grupos.map((g) =>
      `• ${g.turma || "turma aberta na tela"}${g.componente ? " · " + g.componente : ""}: ${g.aulas.length} aula(s)` +
      (g.aulas.some((a) => (a.faltas && a.faltas.length) || (a.justificados && a.justificados.length)) ? " (com faltas/justificados)" : "")
    ).join("\n"));
  }
  const semPeriodo = grupos.flatMap((g) => g.aulas.filter((a) => !a.periodo).map((a) => dataBR(a.data)));
  if (semPeriodo.length) erros.unshift(`Sem período (fora do ano letivo): ${semPeriodo.slice(0, 5).join(", ")}${semPeriodo.length > 5 ? "…" : ""}`);
  erros.slice(0, 8).forEach((e) => { const d = document.createElement("div"); d.className = "erro"; d.textContent = e; el.append(d); });
  if (!linhasDoArquivo) chrome.storage.local.set({ lista: $("lista").value });
  return { grupos, erros, token, origin };
}

$("arquivo").addEventListener("change", async () => {
  const files = [...($("arquivo").files || [])];
  if (!files.length) { linhasDoArquivo = null; atualizarPrevia(); return; }
  try {
    const blocos = [];
    for (const f of files) blocos.push(await linhasDoArquivoEscolhido(f));
    linhasDoArquivo = mesclarPlanilhas(blocos);
    $("lista").value = "";
  } catch (e) {
    linhasDoArquivo = null;
    mostrar("Não consegui ler a planilha: " + e.message, "erro");
  }
  atualizarPrevia();
});
$("lista").addEventListener("input", () => { linhasDoArquivo = null; $("arquivo").value = ""; atualizarPrevia(); });
$("periodo").addEventListener("change", () => { chrome.storage.local.set({ periodo: $("periodo").value }); atualizarPrevia(); });
const hoje = () => { const d = new Date(); return new Date(d - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10); };
$("de").addEventListener("change", () => { chrome.storage.local.set({ de: $("de").value }); atualizarPrevia(); });
$("ate").addEventListener("change", atualizarPrevia);
$("teste").addEventListener("change", () => chrome.storage.local.set({ teste: $("teste").checked }));

function mostrar(texto, classe) { $("status").className = classe || ""; $("status").textContent = texto; }

async function abaDoSiage() {
  const [aba] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!aba || !/^https:\/\/professor\.see\.pb\.gov\.br\//.test(aba.url || "")) return null;
  return aba;
}
async function acordarMotor(aba) {
  try { await chrome.tabs.sendMessage(aba.id, { tipo: "ping" }); }
  catch (e) { await chrome.scripting.executeScript({ target: { tabId: aba.id }, files: ["runner.js"] }); await new Promise((r) => setTimeout(r, 300)); }
  await chrome.tabs.sendMessage(aba.id, { tipo: "iniciar" });
}

async function mostrarTrabalho() {
  const { job } = await chrome.storage.local.get("job");
  if (!job) { $("trabalho").style.display = "none"; return; }
  const todas = job.grupos.flatMap((g) => g.aulas);
  const ok = todas.filter((a) => a.estado === "ok").length;
  const ja = todas.filter((a) => a.estado === "ja").length;
  const erro = todas.filter((a) => a.estado === "erro").length;
  const pend = todas.filter((a) => a.estado === "pendente").length;
  const nome = { rodando: "Em andamento", parado: "Parado", concluido: "Concluído" }[job.status] || job.status;
  const partes = [`${ok} salvas`];
  if (ja) partes.push(`${ja} já no SIAGE`);
  if (erro) partes.push(`${erro} com erro`);
  if (pend) partes.push(`${pend} pendentes`);
  $("trabalhoTexto").textContent = `${nome}: ${partes.join(", ")}${job.teste ? " (modo teste)" : ""}.`;
  $("continuar").style.display = pend && job.status !== "rodando" ? "" : "none";
  $("trabalho").style.display = "block";
}

$("continuar").addEventListener("click", async () => {
  const aba = await abaDoSiage();
  if (!aba) return mostrar("Abra o SIAGE (professor.see.pb.gov.br) nesta aba.", "erro");
  const { job } = await chrome.storage.local.get("job");
  if ($("senha").value) await chrome.storage.session.set({ senha: $("senha").value });
  job.status = "rodando";
  job.teste = false;
  await chrome.storage.local.set({ job });
  await acordarMotor(aba);
  mostrar("Continuando. Acompanhe o painel na página do SIAGE.", "ok");
  mostrarTrabalho();
});
$("limpar").addEventListener("click", async () => {
  await chrome.storage.local.remove("job");
  await chrome.storage.session.remove("senha");
  mostrarTrabalho();
});

$("iniciar").addEventListener("click", async () => {
  const { grupos, erros, token, origin } = atualizarPrevia();
  if (!grupos.length) return mostrar("Escolha a planilha ou cole ao menos uma linha.", "erro");
  if (erros.length) return mostrar("Corrija os problemas marcados em vermelho.", "erro");
  const aba = await abaDoSiage();
  if (!aba) return mostrar("Abra o SIAGE (professor.see.pb.gov.br) nesta aba e tente de novo.", "erro");
  const { job: antigo } = await chrome.storage.local.get("job");
  if (antigo && antigo.status === "rodando") return mostrar("Já há um registro em andamento. Pare pelo painel da página antes.", "erro");
  const teste = $("teste").checked;
  if (teste) { grupos.splice(1); grupos[0].aulas.splice(1); }
  await chrome.storage.session.set({ senha: $("senha").value });
  await chrome.storage.local.set({ job: { status: "rodando", teste, grupos, token: token || "", origin: origin || "", criado: Date.now() } });
  try {
    await acordarMotor(aba);
    mostrar("Começou! Acompanhe o painel no canto da página do SIAGE. Pode fechar esta janela.", "ok");
  } catch (e) {
    mostrar("Erro: " + e.message, "erro");
  }
  mostrarTrabalho();
});

let payloadNotas = null;

function mostrarPreviaNotas() {
  const el = $("previaNotas");
  const escolha = $("escolhaNotas");
  el.innerHTML = "";
  escolha.style.display = "none";
  if (!payloadNotas) return;
  const alunos = payloadNotas.grades || [];
  const turma = (payloadNotas.classroom && payloadNotas.classroom.name) || "turma";
  const bim = payloadNotas.bimester || "?";
  el.textContent = `${turma} · ${bim}º bimestre · ${alunos.length} aluno(s). REC GLOBAL e média ficam com o SIAGE.`;
  escolha.style.display = "block";
}

$("arquivoNotas").addEventListener("change", async () => {
  const f = $("arquivoNotas").files[0];
  payloadNotas = null;
  if (!f) { mostrarPreviaNotas(); return; }
  try {
    const texto = await f.text();
    const json = JSON.parse(texto);
    if (!json || !Array.isArray(json.grades)) throw new Error("JSON sem notas");
    payloadNotas = json;
    mostrarPreviaNotas();
    mostrar("Arquivo de notas carregado. Escolha salvar parcialmente ou lançar.", "ok");
  } catch (e) {
    mostrar("Não li o JSON de notas: " + e.message, "erro");
    mostrarPreviaNotas();
  }
});

async function acordarNotas(aba, saveMode, senha) {
  try { await chrome.tabs.sendMessage(aba.id, { tipo: "ping-notas" }); }
  catch (e) {
    await chrome.scripting.executeScript({ target: { tabId: aba.id }, files: ["grades.js"] });
    await new Promise((r) => setTimeout(r, 300));
  }
  return chrome.tabs.sendMessage(aba.id, { tipo: "iniciar-notas", payload: payloadNotas, saveMode, senha });
}

async function enviarNotas(saveMode) {
  if (!payloadNotas) return mostrar("Escolha o JSON de notas exportado pelo Maestro.", "erro");
  const senha = $("senha").value.trim();
  if (saveMode === "launch" && !senha) {
    return mostrar("Digite a senha do SIAGE (campo acima) para lançar as notas.", "erro");
  }
  if (senha) await chrome.storage.session.set({ senha });
  const aba = await abaDoSiage();
  if (!aba) return mostrar("Abra a tela de notas da turma no SIAGE nesta aba.", "erro");
  try {
    const r = await acordarNotas(aba, saveMode, senha);
    if (!r || !r.ok) return mostrar((r && r.msg) || "Não consegui preencher as notas.", "erro");
    mostrar(r.msg || "Notas enviadas ao SIAGE.", "ok");
  } catch (e) {
    mostrar("Erro: " + e.message, "erro");
  }
}

$("notasParcial").addEventListener("click", () => enviarNotas("partial"));
$("notasLancar").addEventListener("click", () => enviarNotas("launch"));

chrome.storage.local.get(["lista", "teste", "periodo", "de"], (cfg) => {
  $("de").value = cfg.de || "";
  $("ate").value = hoje();
  $("lista").value = cfg.lista || "";
  $("teste").checked = !!cfg.teste;
  $("periodo").value = cfg.periodo || "auto";
  atualizarPrevia();
  mostrarTrabalho();
});
