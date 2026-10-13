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
  let m = s.match(/^(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{2,4})$/);
  if (m) {
    let [, d, mo, a] = m;
    if (a.length === 2) a = "20" + a;
    const dt = new Date(+a, +mo - 1, +d);
    if (dt.getMonth() !== +mo - 1) return null;
    return `${a}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
  }
  m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  return m ? `${m[1]}-${m[2]}-${m[3]}` : null;
}

// Recebe linhas (arrays de células) e monta os grupos turma+componente
function montarGrupos(linhas) {
  const erros = [];
  let col = { data: 0, tempos: 1, turma: 2, componente: 3 };
  let inicio = 0;
  const cab = (linhas[0] || []).map(norm);
  if (cab.some((c) => c === "data")) {
    const achar = (re) => cab.findIndex((c) => re.test(c));
    col = { data: achar(/^data$/), tempos: achar(/^tempo/), turma: achar(/^turma/), componente: achar(/^(componente|disciplina)/) };
    inicio = 1;
  }
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
    const chave = norm(turma) + "|" + norm(componente);
    if (!grupos.has(chave)) grupos.set(chave, { turma, componente, turmaId: null, aulas: [], porData: new Map() });
    const g = grupos.get(chave);
    if (g.porData.has(data)) {
      const a = g.porData.get(data);
      tempos.forEach((t) => { if (!a.tempos.includes(t)) a.tempos.push(t); });
    } else {
      const a = { data, tempos, estado: "pendente", msg: "" };
      g.porData.set(data, a);
      g.aulas.push(a);
    }
  }
  const escolhido = $("periodo").value;
  const lista = [...grupos.values()].filter((g) => g.aulas.length).map(({ porData, ...g }) => {
    g.aulas.sort((a, b) => a.data.localeCompare(b.data));
    g.aulas.forEach((a) => { a.periodo = escolhido === "auto" ? periodoPelaData(a.data) : +escolhido; });
    return g;
  });
  return { grupos: lista, erros };
}

function linhasDoTexto(texto) {
  return texto.split(/\r?\n/).map((l) => (l.includes("\t") ? l.split("\t") : (() => {
    // sem TAB: "23/07/2026 1,2" (só data e tempos)
    const m = l.trim().match(/^(\S+)\s+(.*)$/);
    return m ? [m[1], m[2]] : [l];
  })()));
}

function atual() {
  if (linhasDoArquivo) return montarGrupos(linhasDoArquivo);
  return montarGrupos(linhasDoTexto($("lista").value));
}

function atualizarPrevia() {
  const { grupos, erros } = atual();
  const el = $("previa");
  el.innerHTML = "";
  const total = grupos.reduce((n, g) => n + g.aulas.length, 0);
  if (total) {
    el.append(`${total} aula(s) em ${grupos.length} turma(s):\n` + grupos.map((g) =>
      `• ${g.turma || "turma aberta na tela"}${g.componente ? " · " + g.componente : ""}: ${g.aulas.length} aula(s)`).join("\n"));
  }
  const semPeriodo = grupos.flatMap((g) => g.aulas.filter((a) => !a.periodo).map((a) => dataBR(a.data)));
  if (semPeriodo.length) erros.unshift(`Sem período (fora do ano letivo): ${semPeriodo.slice(0, 5).join(", ")}${semPeriodo.length > 5 ? "…" : ""}`);
  erros.slice(0, 8).forEach((e) => { const d = document.createElement("div"); d.className = "erro"; d.textContent = e; el.append(d); });
  if (!linhasDoArquivo) chrome.storage.local.set({ lista: $("lista").value });
  return { grupos, erros };
}

$("arquivo").addEventListener("change", async () => {
  const f = $("arquivo").files[0];
  if (!f) { linhasDoArquivo = null; atualizarPrevia(); return; }
  try {
    const buf = await f.arrayBuffer();
    let wb;
    if (/\.(csv|txt)$/i.test(f.name)) {
      // CSV do Excel pode vir em UTF-8 ou em Windows-1252
      let texto;
      try { texto = new TextDecoder("utf-8", { fatal: true }).decode(buf); } catch (e) { texto = new TextDecoder("windows-1252").decode(buf); }
      wb = XLSX.read(texto.replace(/^\uFEFF/, ""), { type: "string", cellDates: true });
    } else {
      wb = XLSX.read(buf, { type: "array", cellDates: true });
    }
    const ws = wb.Sheets[wb.SheetNames[0]];
    linhasDoArquivo = XLSX.utils.sheet_to_json(ws, { header: 1, raw: false, dateNF: "dd/mm/yyyy", defval: "" });
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
  const erro = todas.filter((a) => a.estado === "erro").length;
  const pend = todas.filter((a) => a.estado === "pendente").length;
  const nome = { rodando: "Em andamento", parado: "Parado", concluido: "Concluído" }[job.status] || job.status;
  $("trabalhoTexto").textContent = `${nome}: ${ok} salvas, ${erro} com erro, ${pend} pendentes${job.teste ? " (modo teste)" : ""}.`;
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
  const { grupos, erros } = atualizarPrevia();
  if (!grupos.length) return mostrar("Escolha a planilha ou cole ao menos uma linha.", "erro");
  if (erros.length) return mostrar("Corrija os problemas marcados em vermelho.", "erro");
  const aba = await abaDoSiage();
  if (!aba) return mostrar("Abra o SIAGE (professor.see.pb.gov.br) nesta aba e tente de novo.", "erro");
  const { job: antigo } = await chrome.storage.local.get("job");
  if (antigo && antigo.status === "rodando") return mostrar("Já há um registro em andamento. Pare pelo painel da página antes.", "erro");
  const teste = $("teste").checked;
  if (teste) { grupos.splice(1); grupos[0].aulas.splice(1); }
  await chrome.storage.session.set({ senha: $("senha").value });
  await chrome.storage.local.set({ job: { status: "rodando", teste, grupos, criado: Date.now() } });
  try {
    await acordarMotor(aba);
    mostrar("Começou! Acompanhe o painel no canto da página do SIAGE. Pode fechar esta janela.", "ok");
  } catch (e) {
    mostrar("Erro: " + e.message, "erro");
  }
  mostrarTrabalho();
});

chrome.storage.local.get(["lista", "teste", "periodo", "de"], (cfg) => {
  $("de").value = cfg.de || "";
  $("ate").value = hoje();
  $("lista").value = cfg.lista || "";
  $("teste").checked = !!cfg.teste;
  $("periodo").value = cfg.periodo || "auto";
  atualizarPrevia();
  mostrarTrabalho();
});
