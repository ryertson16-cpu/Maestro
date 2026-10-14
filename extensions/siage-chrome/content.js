if (window.__maestroSiageContent) {
  // already listening in this tab
} else {
  window.__maestroSiageContent = true;

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === "SIAGE_PING") {
      sendResponse({ ok: true });
      return;
    }

    if (message?.type !== "SIAGE_FILL") return;

    fillAndConfirm(message.payload || {})
      .then((result) => sendResponse(result))
      .catch((error) => sendResponse({ ok: false, message: error.message }));

    return true;
  });
}

async function fillAndConfirm(payload) {
  const title = pageText();

  if (isAttendancePage(title)) {
    const result = fillAttendance(payload);
    await wait(500);
    return withSave(result, "attendance");
  }

  if (isGradesPage(title)) {
    const result = fillGrades(payload.grades || []);
    await wait(500);
    return withSave(result, "grades");
  }

  if (isLessonRegisterPage(title) || isLessonCalendarPage(title)) {
    return fillLessonRecords(payload);
  }

  return {
    ok: false,
    message: "Abra a tela de aula, frequência ou notas no SIAGE."
  };
}

function isLessonRegisterPage(title) {
  return (/registro de aula/i.test(title) || isLessonCalendarPage(title)) &&
    !isAttendancePage(title) &&
    !isGradesPage(title);
}

function isLessonCalendarPage(title) {
  return /selecione um m[eê]s/i.test(title) ||
    (/legendas/i.test(title) && /n[aã]o registrado/i.test(title));
}

function withSave(result, kind) {
  const saved = confirmOnSiage(kind);

  return {
    ...result,
    message: saved
      ? `${result.message} Registro confirmado no SIAGE.`
      : `${result.message} Não achei o botão Salvar; confirme no portal.`
  };
}

async function fillLessonRecords(payload) {
  const lessons = (payload.lessons && payload.lessons.length
    ? payload.lessons
    : [payload.lesson]
  ).filter((item) => item && (item.date_br || item.date));

  if (!lessons.length) {
    return { ok: false, message: "Este JSON não tem aulas para registrar." };
  }

  dismissSiageDialog();
  await wait(300);

  if (!lessonCalendarModal()) {
    clickNamedButton(["registrar aula"]);
    await wait(800);
  }

  if (!lessonCalendarModal()) {
    return {
      ok: false,
      message: "Abra Registrar Aula no SIAGE até aparecer o calendário de mês e data."
    };
  }

  const dated = lessons
    .map((lesson) => ({ lesson, date: parseLessonDate(lesson) }))
    .filter((item) => item.date)
    .sort((a, b) => a.date - b.date);

  let created = 0;
  const failed = [];
  let monthDebug = "";

  for (const item of dated) {
    dismissSiageDialog();
    await wait(300);

    if (!lessonCalendarModal()) {
      clickNamedButton(["registrar aula"]);
      await wait(900);
    }

    if (!lessonCalendarModal()) {
      failed.push(item.lesson.date_br || formatBr(item.date));
      continue;
    }

    const monthName = MONTHS_PT[item.date.getMonth()];
    const monthResult = await selectLessonMonth(monthName, item.date);
    if (!monthResult) {
      monthDebug = lastMonthDebug;
      failed.push(item.lesson.date_br || formatBr(item.date));
      continue;
    }

    await wait(600);
    const picked = await clickCalendarDay(item.date.getDate());
    if (!picked) {
      failed.push(item.lesson.date_br || formatBr(item.date));
      continue;
    }

    await wait(800);
    await fillLesson(item.lesson);
    await wait(500);

    const registered = clickSiageButton(["registrar"], { skip: ["registrar aula"] });
    if (!registered) {
      failed.push(item.lesson.date_br || formatBr(item.date));
      continue;
    }

    await wait(800);
    dismissSiageDialog();
    await wait(300);

    const saved = clickSiageButton(["salvar"]);
    if (!saved) {
      failed.push(item.lesson.date_br || formatBr(item.date));
      continue;
    }

    created += 1;
    await wait(1100);
    dismissSiageDialog();
    await wait(400);
  }

  const months = [...new Set(dated.map((item) => MONTHS_PT[item.date.getMonth()]))];
  let message = created
    ? `${created} aula(s) registrada(s) no SIAGE.`
    : `Não consegui registrar as aulas em ${months.join(", ")}.`;
  if (failed.length) {
    message += ` Sem data no calendário: ${failed.slice(0, 3).join(", ")}.`;
  }
  if (!created && monthDebug) {
    message += ` ${monthDebug}`;
  }

  return { ok: true, message };
}

const MONTHS_PT = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
];

function parseLessonDate(lesson) {
  if (lesson.date) {
    const [year, month, day] = String(lesson.date).split("-").map(Number);
    if (year && month && day) return new Date(year, month - 1, day);
  }

  if (lesson.date_br) {
    const [day, month, year] = String(lesson.date_br).split("/").map(Number);
    if (year && month && day) return new Date(year, month - 1, day);
  }

  return null;
}

function formatBr(date) {
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  return `${day}/${month}/${date.getFullYear()}`;
}

async function pickLessonCalendarDate(date) {
  const monthName = MONTHS_PT[date.getMonth()];
  const monthOk = await selectLessonMonth(monthName, date);
  if (!monthOk) return false;
  await wait(500);
  return clickCalendarDay(date.getDate());
}

function callPage(action, params) {
  return new Promise((resolve) => {
    const id = `siage-${Date.now()}-${Math.random()}`;

    const onMessage = (event) => {
      if (event.source !== window) return;
      const data = event.data;
      if (!data || data.source !== "maestro-siage-result" || data.id !== id) return;
      window.removeEventListener("message", onMessage);
      resolve(data);
    };

    window.addEventListener("message", onMessage);
    window.postMessage({ source: "maestro-siage", id, action, ...params }, "*");

    setTimeout(() => {
      window.removeEventListener("message", onMessage);
      resolve({ ok: false, message: "timeout" });
    }, 8000);
  });
}

function lessonCalendarModal() {
  const matches = [...document.querySelectorAll("div, section, aside, dialog")].filter((el) => {
    const text = el.innerText || "";
    return /selecione um m[eê]s e uma data/i.test(text) &&
      /legendas/i.test(text) &&
      text.length < 12000;
  });
  return matches.sort((a, b) => (b.innerText || "").length - (a.innerText || "").length)[0] || null;
}

let lastMonthDebug = "";

async function selectLessonMonth(monthName, date) {
  const modal = lessonCalendarModal() || document;
  if (monthIsSelected(modal, monthName, date)) return true;

  const pageResult = await callPage("selectMonth", {
    monthName,
    year: date?.getFullYear(),
    month: date ? date.getMonth() + 1 : undefined
  });
  lastMonthDebug = pageResult?.debug || pageResult?.message || "";
  return Boolean(pageResult?.ok || monthIsSelected(lessonCalendarModal() || modal, monthName, date));
}

function monthSelectorTrigger(modal) {
  const label = [...modal.querySelectorAll("label, span, p, small, strong, legend")].find((el) => {
    const text = normalize(el.innerText || "");
    return text === "mes" || (text.startsWith("mes") && text.length < 24);
  });

  let node = label;
  for (let i = 0; i < 6 && node; i += 1) {
    const found = findMonthControl(node);
    if (found) return found;
    node = node.parentElement;
  }

  return findMonthControl(modal);
}

function findMonthControl(root) {
  if (!root?.querySelectorAll) return null;

  const visibleSelect = [...root.querySelectorAll("select")].find((el) => isVisible(el));
  if (visibleSelect) return visibleSelect;

  return root.querySelector([
    ".ui-autocomplete-dropdown",
    ".p-autocomplete-dropdown",
    ".ui-dropdown-trigger",
    ".p-dropdown-trigger",
    ".p-select-dropdown",
    "input.ui-autocomplete-input",
    "input.ui-inputtext",
    "[role='combobox']",
    ".p-dropdown-label",
    ".p-select-label",
    "p-autocomplete",
    ".ui-autocomplete",
    ".p-dropdown",
    ".p-select"
  ].join(", "));
}

function monthIsSelected(modal, monthName, date) {
  const wanted = normalize(monthName);
  const heading = [...modal.querySelectorAll("*")].filter((el) => {
    if (!isVisible(el) || el.tagName === "INPUT" || el.tagName === "SELECT") return false;
    const text = (el.innerText || "").trim();
    return MONTHS_PT.includes(text);
  });
  const leaves = heading.filter((el) => !heading.some((other) => other !== el && el.contains(other)));
  const title = leaves.filter((el) => !el.closest("p-autocomplete")).pop() || leaves[leaves.length - 1];
  if (!title || normalize(title.innerText) !== wanted) return false;
  if (!date) return true;
  const expected = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  const nums = [...modal.querySelectorAll("button, span, div, td, a")].map((el) => {
    const text = (el.innerText || "").trim();
    if (!/^\d{1,2}$/.test(text)) return 0;
    const box = el.getBoundingClientRect();
    if (box.width < 18 || box.width > 90) return 0;
    return Number(text);
  }).filter((n) => n >= 1 && n <= 31);
  const last = nums.length ? Math.max(...nums) : 0;
  return !last || last === expected;
}

async function waitForMonthOption(monthName) {
  for (let step = 0; step < 10; step += 1) {
    const option = [...document.querySelectorAll(
      ".ui-autocomplete-list-item, .p-autocomplete-item, .ui-dropdown-item, .p-dropdown-item, .p-select-option, .p-dropdown-overlay li, .p-select-overlay li, mat-option, [role='option'], li"
    )].find((el) => {
      if (!isVisible(el)) return false;
      return (el.innerText || "").trim() === monthName;
    });

    if (option) return option;
    await wait(120);
  }

  return [...document.querySelectorAll("[role='option'], li, span, div")].find((el) => {
    if (!isVisible(el)) return false;
    const text = (el.innerText || "").trim();
    return text === monthName && text.length < 16 && el.getClientRects().length;
  }) || null;
}

function setNativeSelectValue(select, value) {
  const proto = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, "value");
  if (proto?.set) proto.set.call(select, value);
  else select.value = value;

  select.dispatchEvent(new Event("input", { bubbles: true }));
  select.dispatchEvent(new Event("change", { bubbles: true }));
}

function isVisible(el) {
  if (!el || el.nodeType !== 1) return false;

  const style = window.getComputedStyle(el);
  if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) {
    return false;
  }

  const rect = el.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
}

function clickOptionByText(value) {
  const match = [...document.querySelectorAll("li, option, span, div, button")].find((el) => {
    const text = (el.innerText || el.textContent || "").trim();
    return text === value;
  });

  if (match) safeClick(match);
}

async function clickCalendarDay(day) {
  const pageResult = await callPage("clickDay", { day });
  if (pageResult?.ok) return true;

  const modal = lessonCalendarModal() || document;
  const labels = [String(day), String(day).padStart(2, "0")];
  const candidates = [...modal.querySelectorAll("button, td, span, div, a")].filter((el) => {
    if (el.disabled) return false;
    const text = (el.innerText || "").trim();
    if (!labels.includes(text)) return false;
    if (!isVisible(el)) return false;
    const box = el.getBoundingClientRect();
    return box.width >= 18 && box.width <= 90 && box.height >= 14 && box.height <= 90;
  });

  const leaves = candidates.filter((el) => {
    return ![...el.children].some((child) => labels.includes((child.innerText || "").trim()));
  });

  const inCalendar = (leaves.length ? leaves : candidates).filter((el) => {
    return el.closest("table, .p-datepicker, [class*='calendar'], [class*='datepicker']") ||
      /calendar|datepicker|p-datepicker/i.test(`${el.className} ${el.parentElement?.className || ""}`);
  });

  const target = inCalendar[0] || leaves.find((el) => el.tagName === "BUTTON") || leaves[0];
  if (!target) return false;

  target.click();
  return true;
}

function dismissSiageDialog() {
  const button = [...document.querySelectorAll("button")].find((el) => {
    return normalize(el.innerText || "") === "ok";
  });

  if (button) safeClick(button);
}

function clickNamedButton(names) {
  const buttons = [...document.querySelectorAll("button, a, [role='button']")];
  const match = buttons.find((button) => {
    const text = normalize(button.innerText || button.value || "");
    if (/buscar|limpar|calendario|desmarcar|voltar|cancelar/.test(text)) return false;
    return names.some((name) => text === name || text.startsWith(name));
  });

  if (!match) return false;
  safeClick(match);
  return true;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function confirmOnSiage(kind) {
  if (kind === "lesson") {
    return clickSiageButton(["registrar"], { skip: ["registrar aula"] });
  }

  const preferred =
    kind === "attendance"
      ? ["salvar", "confirmar", "registrar frequencia", "gravar"]
      : ["salvar", "confirmar", "gravar"];

  return clickSiageButton(preferred);
}

function clickSiageButton(preferred, options = {}) {
  const skip = options.skip || [];
  const buttons = [...document.querySelectorAll("button, input[type='submit'], [role='button']")];

  const match = buttons.find((button) => {
    if (button.disabled) return false;
    const text = normalize(button.innerText || button.value || "");
    if (!text || /buscar|limpar|desmarcar|voltar|cancelar|fechar|^ok$/.test(text)) return false;
    if (skip.some((label) => text === label || text.startsWith(`${label} `))) return false;
    return preferred.some((label) => text === label);
  }) || buttons.find((button) => {
    if (button.disabled) return false;
    const text = normalize(button.innerText || button.value || "");
    if (!text || /buscar|limpar|desmarcar|voltar|cancelar|fechar|^ok$/.test(text)) return false;
    if (skip.some((label) => text === label || text.startsWith(`${label} `))) return false;
    return preferred.some((label) => text.startsWith(`${label} `));
  });

  if (!match) return false;
  safeClick(match);
  return true;
}

function isAttendancePage(title) {
  return /desmarcar todos/i.test(title) ||
    (/informa[cç][oõ]es sobre a aula/i.test(title) && /1[ºo]?\s*tempo/i.test(title));
}

function isGradesPage(title) {
  return /1[ªa]\s*unidade/i.test(title) &&
    /rec\s*\/?\s*rep/i.test(title);
}

async function fillLesson(lesson) {
  fillLabeledField(["data"], lesson.date_br || toBrDate(lesson.date));
  fillLabeledField(["período", "periodo"], lesson.period);
  fillLabeledField(["modo de aula"], lesson.class_mode);
  fillLabeledField(["tipo de aula"], lesson.class_type);
  await fillLessonPlan(lesson);

  return {
    ok: true,
    message: "Dados da aula e plano de ensino preenchidos."
  };
}

async function fillLessonPlan(lesson) {
  const plan = lesson.plan || buildLessonPlan(lesson);

  await selectDropdownOption(["plano de ensino"], plan.teaching_plan);
  await wait(700);
  await selectDropdownOption(["unidade tematica", "unidade temática"], plan.thematic_unit);
  await wait(500);
  await selectDropdownOption(["objetos de conhecimento"], plan.knowledge_objects);
  await wait(400);
  await selectDropdownOption(["competencias", "competências", "campo de experiencias", "campo de experiências"], plan.competencies);
  await wait(400);
  await selectDropdownOption(["habilidade"], plan.skills);
  await wait(400);
  await selectDropdownOption(["metodologia"], plan.methodology);
  fillEmptyArea(["metodologia"], plan.methodology);
  fillEmptyArea(["observacoes", "observações"], plan.observations);
}

function buildLessonPlan(lesson) {
  const theme = String(lesson.theme || "os conteúdos da aula").trim();
  const objective = String(lesson.objective || "").trim();
  const content = String(lesson.content || "").trim();
  const methodology = String(lesson.methodology || "").trim();
  const date = lesson.date_br || toBrDate(lesson.date);

  return {
    teaching_plan: lesson.course_name ? `${lesson.course_name} — plano de ensino vigente` : "Plano de ensino da componente curricular",
    thematic_unit: `Unidade temática: ${theme}`,
    knowledge_objects: content || `Objetos de conhecimento relacionados a ${theme}, com ênfase na aplicação prática dos conteúdos da aula.`,
    competencies: objective || `Compreender e aplicar ${theme}, articulando conceitos, procedimentos e atitudes no contexto da formação técnica.`,
    skills: `Identificar, analisar e registrar ${theme}; utilizar os procedimentos trabalhados na aula; comunicar os resultados com clareza.`,
    methodology: methodology || (
      /avalia/i.test(lesson.class_mode || "")
        ? `Avaliação alinhada ao tema ${theme}, com orientação inicial, realização da atividade e devolutiva dos critérios de correção.`
        : `Exposição dialogada sobre ${theme}, seguida de atividade prática, acompanhamento do professor e síntese coletiva.`
    ),
    observations: `Registro da aula de ${date} sobre ${theme}. Campos pedagógicos preenchidos de forma consistente a partir do tema, objetivo, conteúdo e metodologia lançados no Maestro.`
  };
}

function fillEmptyArea(labels, value) {
  if (!value) return;
  const field = findFieldByLabel(labels);
  if (!field || !["INPUT", "TEXTAREA"].includes(field.tagName)) return;
  if (field.type === "hidden") return;
  const current = String(field.value || "").trim();
  if (current && !/^selecione$/i.test(current)) return;
  setValue(field, value);
}

async function selectDropdownOption(labels, preferredValue) {
  const field = findFieldByLabel(labels);
  if (field?.tagName === "SELECT") {
    const options = [...field.options].filter((option) => {
      const text = (option.textContent || "").trim();
      return option.value && !/^selecione$/i.test(text);
    });
    const match = options.find((option) => namesMatch(option.textContent, preferredValue)) || options[0];
    if (!match) return false;
    setValue(field, match.textContent);
    return true;
  }

  const labelNode = findLabelNode(labels);
  const root = labelNode?.closest("div, p-autocomplete, p-dropdown, p-select") || labelNode?.parentElement;
  const trigger = root?.querySelector(
    "select, [role='combobox'], .ui-autocomplete-dropdown, .p-dropdown-trigger, input.ui-inputtext, input"
  ) || field;

  if (!trigger) return false;
  trigger.click();
  await wait(400);

  const options = [...document.querySelectorAll(
    ".ui-autocomplete-list-item, .p-dropdown-item, .p-select-option, [role='option'], li"
  )].filter((el) => {
    if (!isVisible(el)) return false;
    const text = (el.innerText || "").trim();
    return text && text.length < 220 && !/^selecione$/i.test(text);
  });

  const match = options.find((el) => namesMatch(el.innerText, preferredValue)) || options[0];
  if (!match) return false;
  match.click();
  return true;
}

function findLabelNode(labels) {
  const nodes = [...document.querySelectorAll("label, span, p, div, strong, legend")];
  return nodes.find((node) => {
    const text = normalize(node.textContent || "");
    return labels.some((label) => text === normalize(label));
  }) || nodes.find((node) => {
    const text = normalize(node.textContent || "");
    return labels.some((label) => text.startsWith(normalize(label)) && text.length < 48);
  });
}

function fillAttendance(payload) {
  const rows = payload.attendance || [];
  const siageRows = listAttendanceRows();
  let filled = 0;
  const missing = [];

  rows.forEach((row) => {
    const match = bestAttendanceRow(siageRows, row.name || row.name_key);
    if (!match) {
      missing.push(row.name);
      return;
    }

    try {
      setAttendanceToggle(match.row, match.control, desiredAttendanceState(row));
      filled += 1;
    } catch (_error) {
      missing.push(row.name);
    }
  });

  return {
    ok: true,
    message: attendanceMessage(filled, rows.length, missing)
  };
}

function fillGrades(grades) {
  const siageRows = listGradeRows();
  let filled = 0;
  const missing = [];

  grades.forEach((row) => {
    const match = bestAttendanceRow(siageRows, row.name || row.name_key);
    if (!match) {
      missing.push(row.name);
      return;
    }

    const unit1 = row.units?.find((unit) => unit.number === 1) || {};
    const unit2 = row.units?.find((unit) => unit.number === 2) || {};
    const unit3 = row.units?.find((unit) => unit.number === 3) || {};
    const values = [
      unit1.score,
      unit1.recovery,
      unit2.score,
      unit2.recovery,
      unit3.score,
      unit3.recovery
    ];

    values.forEach((value, index) => {
      if (value == null || !match.inputs[index]) return;
      setValue(match.inputs[index], formatGrade(filledValue));
    });

    filled += 1;
  });

  let message = `Notas preenchidas para ${filled} de ${grades.length} aluno(s). A média do período deve ser calculada pelo SIAGE.`;
  if (missing.length) {
    message += ` Não encontrado: ${missing.slice(0, 3).join(", ")}.`;
  }

  return { ok: true, message };
}

function listGradeRows() {
  const rows = [...document.querySelectorAll("table tbody tr, table tr, [class*='p-datatable-row']")];
  const items = [];

  rows.forEach((row) => {
    const inputs = [...row.querySelectorAll("input")].filter((input) => {
      return !input.disabled &&
        !input.readOnly &&
        input.type !== "hidden" &&
        input.type !== "checkbox" &&
        input.type !== "search";
    });

    const name = studentNameFromRow(row, inputs[0]);
    if (!name || inputs.length < 2) return;
    if (normalize(name) === "estudantes" || /unidade/.test(normalize(name))) return;

    items.push({ row, name, inputs, control: inputs[0] });
  });

  return items;
}

function formatGrade(value) {
  return String(value).replace(".", ",");
}

function fillNamedRows(rows, applyRow) {
  const tableRows = [...document.querySelectorAll("table tbody tr, table tr, [role='row']")];
  let filled = 0;

  rows.forEach((row) => {
    const match = tableRows.find((tr) => rowMatchesStudent(tr, row.name_key || row.name));
    if (!match) return;

    applyRow(match, row);
    filled += 1;
  });

  return filled;
}

function rowMatchesStudent(el, name) {
  const firstCell = el.querySelector("td, th");
  const text = firstCell ? firstCell.innerText : el.innerText.split("\n")[0];
  return namesMatch(text, name);
}

function fillLabeledField(labels, value, root = document) {
  if (!value) return;

  const field = findFieldByLabel(labels, root);
  if (field) setValue(field, value);
}

function attendanceHeaderRoot() {
  const heading = [...document.querySelectorAll("h1, h2, h3, legend, div, span, p")].find((node) => {
    const text = (node.textContent || "").trim();
    return /informa[cç][oõ]es sobre a aula/i.test(text) && text.length < 80;
  });

  return heading?.closest("form, section, article, main, .card, [class*='container']") || document;
}

function findFieldByLabel(labels, root = document) {
  const nodes = [...root.querySelectorAll("label, span, p, div, strong, legend")];

  const labelNode = nodes.find((node) => {
    const text = normalize(node.textContent || "");
    return labels.some((label) => text === normalize(label));
  }) || nodes.find((node) => {
    const text = normalize(node.textContent || "");
    return labels.some((label) => text.startsWith(normalize(label)) && text.length < 40);
  });

  if (!labelNode) return null;
  if (labelNode.control) return labelNode.control;
  if (labelNode.htmlFor) return document.getElementById(labelNode.htmlFor);

  return collectFields(labelNode.parentElement || labelNode)[0] ||
    collectFields(labelNode.nextElementSibling)[0];
}

function collectFields(root) {
  if (!root) return [];

  return [...root.querySelectorAll("input, select, textarea")].filter((field) => {
    return !field.disabled && field.type !== "hidden";
  });
}

function listAttendanceRows() {
  const controls = [...document.querySelectorAll(
    ".p-inputswitch, .p-toggleswitch, [role='switch'], input[type='checkbox']"
  )];
  const seen = new Set();
  const items = [];

  controls.forEach((control) => {
    if (control.closest("thead, .p-datatable-thead, header, nav")) return;

    const row = control.closest("tr") ||
      control.closest("[class*='p-datatable-row']") ||
      control.closest("[class*='row']");

    if (!row || seen.has(row)) return;

    const name = studentNameFromRow(row, control);
    if (!name || normalize(name) === "nome") return;

    seen.add(row);
    items.push({
      row,
      control: control.closest(".p-inputswitch, .p-toggleswitch") || control,
      name
    });
  });

  return items;
}

function studentNameFromRow(row, control) {
  const cells = [...row.querySelectorAll("td")];
  const nameCell = cells.find((td) => !td.contains(control));
  const text = ((nameCell || cells[0] || row).innerText || "").trim();
  return text.split("\n")[0].trim();
}

function bestAttendanceRow(items, maestroName) {
  let best = null;
  let bestScore = 0;

  items.forEach((item) => {
    const score = nameScore(item.name, maestroName);
    if (score > bestScore) {
      best = item;
      bestScore = score;
    }
  });

  return bestScore >= 2 ? best : null;
}

function nameScore(siageName, maestroName) {
  const siage = normalize(siageName);
  const maestro = normalize(maestroName);
  if (!siage || !maestro) return 0;
  if (siage === maestro) return 100;
  if (siage.startsWith(maestro) || maestro.startsWith(siage)) return 50;

  const a = nameTokens(siageName);
  const b = nameTokens(maestroName);
  return b.filter((token) => a.includes(token)).length;
}

function nameTokens(value) {
  return normalize(value).split(" ").filter((token) => token.length > 1);
}

function setAttendanceToggle(row, control, desired) {
  const clickTarget = row.querySelector(".p-inputswitch-slider, .p-toggleswitch-slider") || control;

  if (desired === "absent") {
    if (isSwitchOn(row, control)) safeClick(clickTarget);
    return;
  }

  if (desired === "present") {
    if (attendanceState(row) === "justified") safeClick(clickTarget);
    if (!isSwitchOn(row, control)) safeClick(clickTarget);
    return;
  }

  for (let step = 0; step < 4; step += 1) {
    if (attendanceState(row) === "justified") return;
    safeClick(clickTarget);
  }
}

function isSwitchOn(row, control) {
  const sw = row.querySelector(".p-inputswitch, .p-toggleswitch") || control;
  if (sw?.classList?.contains("p-inputswitch-checked")) return true;
  if (sw?.classList?.contains("p-toggleswitch-checked")) return true;
  if (sw?.getAttribute("aria-checked") === "true") return true;

  const checkbox = row.querySelector("input[type='checkbox']");
  return Boolean(checkbox?.checked);
}

function safeClick(el) {
  if (!el) return;
  el.click();
}

function attendanceControl(root) {
  return root.querySelector("input[type='checkbox']") ||
    root.querySelector("[role='switch'], button.switch, .p-inputswitch, .form-switch");
}

function desiredAttendanceState(row) {
  const status = row.status || row.siage_status;

  if (status === "absent" || status === "faltou") return "absent";
  if (status === "justified" || status === "justificado") return "justified";
  return "present";
}

function attendanceState(root) {
  const checkbox = root.querySelector("input[type='checkbox']");
  const visual =
    root.querySelector("[role='switch'], .p-inputswitch, .p-inputswitch-slider, .switch, .toggle") ||
    checkbox?.closest("label, div, span, td") ||
    checkbox;

  const on = checkbox
    ? checkbox.checked
    : visual?.getAttribute("aria-checked") === "true" ||
      /checked|active|on/i.test(visual?.className || "");

  const color = visualColor(visual);
  if (isBlue(color) || /justif|info|azul|blue/i.test(`${visual?.className || ""} ${root.className || ""}`)) {
    return "justified";
  }

  if (!on && !isGreen(color)) return "absent";
  return "present";
}

function visualColor(el) {
  if (!el || el.nodeType !== 1) return "";

  const nodes = [el, el.parentElement];

  try {
    nodes.push(...el.querySelectorAll("span, div, button"));
  } catch (_error) {
    // ignore non-element nodes
  }

  const colors = nodes.filter(Boolean).map((node) => computedBackground(node));
  return colors.find((color) => isGreen(color) || isBlue(color)) || computedBackground(el);
}

function computedBackground(el) {
  try {
    return window.getComputedStyle(el).backgroundColor;
  } catch (_error) {
    return "";
  }
}

function rgb(color) {
  const match = String(color).match(/\d+/g);
  if (!match || match.length < 3) return null;
  return match.slice(0, 3).map(Number);
}

function isBlue(color) {
  const value = rgb(color);
  if (!value) return false;
  const [red, green, blue] = value;
  return blue > 110 && blue > red + 25 && blue >= green;
}

function isGreen(color) {
  const value = rgb(color);
  if (!value) return false;
  const [red, green, blue] = value;
  return green > 110 && green > red && green > blue;
}

function setValue(field, value) {
  if (!field || !["INPUT", "SELECT", "TEXTAREA"].includes(field.tagName)) return;

  if (field.tagName === "SELECT") {
    const option = [...field.options].find((item) =>
      namesMatch(item.textContent, value) || namesMatch(item.value, value)
    );

    if (option) field.value = option.value;
  } else {
    field.focus();
    field.value = value;
  }

  field.dispatchEvent(new Event("input", { bubbles: true }));
  field.dispatchEvent(new Event("change", { bubbles: true }));
  field.blur();
}

function namesMatch(left, right) {
  const a = normalize(left);
  const b = normalize(right);
  return a === b || a.includes(b);
}

function normalize(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function toBrDate(value) {
  if (!value) return "";
  const [year, month, day] = String(value).split("-");
  if (!day) return value;
  return `${day}/${month}/${year}`;
}

function pageText() {
  return document.body.innerText || "";
}

function attendanceMessage(filled, total, missing = []) {
  if (!total) {
    return "Nenhum aluno no JSON de frequência.";
  }

  let message = `Frequência: ${filled} de ${total} aluno(s) ajustados (verde = presente, azul = justificada, desligado = falta).`;

  if (missing.length) {
    message += ` Não encontrado: ${missing.slice(0, 3).join(", ")}.`;
  }

  return `${message} Confira antes de salvar.`;
}
