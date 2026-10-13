if (!window.__maestroSiagePage) {
  window.__maestroSiagePage = true;

  const MONTHS = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  ];

  window.addEventListener("message", (event) => {
    if (event.source !== window) return;
    const data = event.data;
    if (!data || data.source !== "maestro-siage") return;

    Promise.resolve()
      .then(() => handle(data))
      .then((result) => {
        window.postMessage({
          source: "maestro-siage-result",
          id: data.id,
          ...result
        }, "*");
      })
      .catch((error) => {
        window.postMessage({
          source: "maestro-siage-result",
          id: data.id,
          ok: false,
          message: error.message
        }, "*");
      });
  });

  async function handle(data) {
    if (data.action === "selectMonth") {
      return selectMonth(data.monthName, Number(data.year), Number(data.month));
    }
    if (data.action === "clickDay") return { ok: clickDay(data.day) };
    return { ok: false, message: "ação desconhecida" };
  }

  async function selectMonth(monthName, year, month) {
    dismissError();
    await sleep(200);

    const modal = calendarModal();
    if (!modal) return { ok: false, message: "modal não encontrado" };
    if (monthSelected(modal, monthName, year, month)) return { ok: true };

    const widget = monthWidget(modal);
    const input = monthInput(widget, modal);
    const auto = modal.querySelector("p-autocomplete") || widget;
    const safeDate = new Date(year || new Date().getFullYear(), (month || 1) - 1, 1);
    const cmp = hostComponent(auto) || hostComponent(widget) || hostComponent(input);
    const currentName = MONTHS.find((name) => {
      return name === (cmp?.value || input?.value || "Outubro");
    }) || String(cmp?.value || input?.value || "");

    try {
      setMonthOnParents(auto, currentName, monthName, safeDate);
    } catch (_error) {
      // keep going
    }
    try {
      await confirmMonthSelection(cmp, monthName, input, widget);
    } catch (_error) {
      dismissError();
    }
    detectAll(auto, cmp);

    for (let step = 0; step < 20; step += 1) {
      dismissError();
      if (monthSelected(calendarModal() || modal, monthName, year, month)) return { ok: true };
      await sleep(150);
    }

    return {
      ok: monthSelected(calendarModal() || modal, monthName, year, month),
      debug: debugMonth(calendarModal() || modal, input || widget, cmp, auto)
    };
  }

  function calendarModal() {
    const matches = [...document.querySelectorAll("div, section, aside, dialog")].filter((el) => {
      const text = el.innerText || "";
      return /selecione um m[eê]s e uma data/i.test(text) &&
        /legendas/i.test(text) &&
        text.length < 12000 &&
        visible(el);
    });
    const withTitle = matches.find((el) => calendarHeading(el));
    return withTitle || matches.sort((a, b) => (b.innerText || "").length - (a.innerText || "").length)[0] || null;
  }

  function monthWidget(modal) {
    const label = [...modal.querySelectorAll("label, span, p, small, strong, legend")].find((el) => {
      const text = norm(el.innerText || "");
      return text === "mes" || (text.startsWith("mes") && text.length < 24);
    });
    const area = label?.closest("div")?.parentElement || label?.parentElement || modal;
    return area.querySelector("p-autocomplete, p-dropdown, p-select, .ui-autocomplete, .ui-dropdown, .p-autocomplete, .p-dropdown") ||
      modal.querySelector("p-autocomplete, p-dropdown, p-select, .ui-autocomplete, .ui-dropdown, .p-autocomplete, .p-dropdown");
  }

  function monthInput(widget, modal) {
    const root = widget || modal;
    return [...root.querySelectorAll("input")].find((el) => {
      if (el.type === "hidden" || !visible(el)) return false;
      const cls = String(el.className || "");
      const value = (el.value || "").trim();
      return /ui-inputtext|autocomplete|dropdown|p-inputtext/i.test(cls) || MONTHS.includes(value);
    }) || [...root.querySelectorAll("input")].find((el) => el.type !== "hidden" && visible(el));
  }

  function monthChevron(widget, input) {
    const root = widget || input?.parentElement;
    const specific = root?.querySelector([
      ".ui-autocomplete-dropdown",
      ".p-autocomplete-dropdown",
      ".ui-dropdown-trigger",
      ".p-dropdown-trigger",
      ".p-select-dropdown"
    ].join(", "));
    if (specific) return specific;

    if (!input?.parentElement) return null;
    return [...input.parentElement.querySelectorAll("button, .pi-chevron-down")].find((el) => {
      return !/fechar|ok|salvar|buscar/i.test(el.innerText || "");
    }) || null;
  }

  function hostComponent(el) {
    if (!el) return null;
    if (window.ng?.getComponent) {
      try {
        const cmp = window.ng.getComponent(el);
        if (cmp) return cmp;
      } catch (_error) {
        // ignore
      }
    }

    const ctx = el.__ngContext__;
    if (!ctx) return null;
    if (Array.isArray(ctx)) {
      if (ctx[8] && typeof ctx[8] === "object") return ctx[8];
      return ctx.find((item) => item && typeof item === "object" && (
        typeof item.selectItem === "function" ||
        typeof item.handleDropdownClick === "function" ||
        item.suggestions ||
        typeof item.onModelChange === "function"
      )) || null;
    }
    return null;
  }

  async function confirmMonthSelection(cmp, monthName, input, widget) {
    if (!cmp || !monthName) return false;

    let options = Array.isArray(cmp.suggestions) ? cmp.suggestions : [];
    if (typeof cmp.optionsForAutocomplete === "function") {
      try {
        const result = cmp.optionsForAutocomplete({ query: "" }) || cmp.optionsForAutocomplete(monthName);
        options = result && typeof result.then === "function" ? await result : (result || options);
      } catch (_error) {
        // ignore
      }
    }
    if (!options?.length) options = MONTHS.slice();
    cmp.suggestions = options;

    const picked = options.find((item) => {
      const text = typeof item === "string" ? item : (item?.nome || item?.label || item?.name || item?.descricao || item?.value || "");
      return isMonthText(String(text), monthName);
    }) || monthName;

    runInZone(cmp, () => {
      if (typeof cmp.selectToAutocomplete === "function") cmp.selectToAutocomplete(picked);
      if (typeof cmp.onValueChange === "function") {
        try {
          cmp.onValueChange(picked);
        } catch (_error) {
          try { cmp.onValueChange({ value: picked }); } catch (_ignored) { /* ignore */ }
        }
      }
      if (cmp.onValueChange?.emit) cmp.onValueChange.emit(picked);
      if (cmp.onSelect?.emit) cmp.onSelect.emit(picked);
      if (typeof cmp.onModelChange === "function") cmp.onModelChange(picked);
      cmp.value = picked;
      cmp.cd?.markForCheck?.();
      cmp.cd?.detectChanges?.();
    });

    const chevron = monthChevron(widget, input);
    if (chevron) chevron.click();
    await sleep(350);
    const option = findMonthOption(monthName);
    if (option) {
      option.click();
      await sleep(400);
    }
    return true;
  }

  function setMonthOnParents(start, fromName, toName, safeDate) {
    let node = start;
    for (let hop = 0; hop < 24 && node; hop += 1) {
      const cmp = hostComponent(node);
      if (cmp && cmp.constructor?.name !== "AutoCompleteComponent") {
        runInZone(cmp, () => {
          Object.keys(cmp).forEach((key) => {
            if (key.startsWith("_") || key === "value") return;
            let value;
            try {
              value = cmp[key];
            } catch (_error) {
              return;
            }
            if (value === fromName) cmp[key] = toName;
          });

          cmp.cd?.markForCheck?.();
          cmp.cd?.detectChanges?.();
        });
      }
      node = node.parentElement;
    }
  }

  function detectAll(el, cmp) {
    runInZone(cmp, () => {
      cmp?.cd?.detectChanges?.();
    });
    let node = el;
    for (let hop = 0; hop < 12 && node; hop += 1) {
      const host = hostComponent(node);
      try {
        host?.cd?.detectChanges?.();
      } catch (_error) {
        // ignore
      }
      node = node.parentElement;
    }
  }

  function fakeEvent() {
    const originalEvent = new Event("click", { bubbles: true, cancelable: true });
    return {
      originalEvent,
      preventDefault() {},
      stopPropagation() {},
      target: originalEvent.target
    };
  }

  function monthModelValue(current, option, monthName, safeDate, monthNumber) {
    if (typeof current === "string") return monthName;
    if (option != null && typeof option === "object") {
      return { ...option, dia: 1, day: 1, data: safeDate, date: safeDate };
    }
    if (option != null && typeof option === "string") return option;
    if (option != null && typeof option === "number") return option;
    if (current instanceof Date) return safeDate;
    if (typeof current === "number") return monthNumber;
    if (current && typeof current === "object") {
      return {
        ...current,
        ano: safeDate.getFullYear(),
        year: safeDate.getFullYear(),
        mes: monthNumber,
        month: monthNumber,
        dia: 1,
        day: 1,
        data: safeDate,
        date: safeDate
      };
    }
    return monthName;
  }

  function setHiddenSelect(root, monthName, monthNumber) {
    if (!root?.querySelectorAll) return false;
    const select = [...root.querySelectorAll("select")].find((el) => {
      return [...el.options].some((option) => isMonthText(option.textContent || "", monthName) || Number(option.value) === monthNumber);
    });
    if (!select) return false;

    const option = [...select.options].find((item) => {
      return isMonthText(item.textContent || "", monthName) || Number(item.value) === monthNumber;
    });
    if (!option) return false;

    const proto = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, "value");
    if (proto?.set) proto.set.call(select, option.value);
    else select.value = option.value;
    select.dispatchEvent(new Event("input", { bubbles: true }));
    select.dispatchEvent(new Event("change", { bubbles: true }));
    return true;
  }

  function runInZone(component, fn) {
    const zone = findNgZone(component);
    if (zone?.run) {
      return zone.run(fn);
    }
    if (typeof Zone !== "undefined" && Zone.current?.run) {
      return Zone.current.run(fn);
    }
    return fn();
  }

  function findNgZone(obj) {
    if (!obj || typeof obj !== "object") return null;
    if (typeof obj.run === "function" && typeof obj.runOutsideAngular === "function") return obj;

    for (const key of ["zone", "ngZone", "_ngZone"]) {
      const value = obj[key];
      if (value && typeof value.run === "function" && typeof value.runOutsideAngular === "function") {
        return value;
      }
    }

    try {
      for (const key of Object.keys(obj)) {
        const value = obj[key];
        if (value && typeof value.run === "function" && typeof value.runOutsideAngular === "function") {
          return value;
        }
      }
    } catch (_error) {
      // ignore
    }

    return null;
  }

  function angularComponent(el) {
    let node = el;
    while (node) {
      if (window.ng?.getComponent) {
        try {
          const cmp = window.ng.getComponent(node);
          if (cmp && looksLikeSelect(cmp)) return cmp;
        } catch (_error) {
          // ignore
        }
      }

      const ctx = node.__ngContext__;
      const found = searchContext(ctx);
      if (found) return found;
      node = node.parentElement;
    }
    return null;
  }

  function searchContext(ctx) {
    if (!ctx) return null;
    const pile = [];
    if (Array.isArray(ctx)) pile.push(...ctx);
    else pile.push(ctx);
    if (Array.isArray(ctx.lView)) pile.push(...ctx.lView);

    for (const item of pile) {
      if (looksLikeSelect(item)) return item;
    }
    return null;
  }

  function looksLikeSelect(item) {
    if (!item || typeof item !== "object") return false;
    if (typeof item.handleDropdownClick === "function") return true;
    if (typeof item.writeValue === "function" && typeof item.onModelChange === "function") {
      const value = item.value;
      if (value instanceof Date) return true;
      if (value && typeof value === "object" && (value.mes != null || value.month != null || value.ano != null)) return true;
    }
    const hasOptions = item.options || item._options || item.filteredOptions || item.suggestions;
    const hasValue = "value" in item || "model" in item || typeof item.onModelChange === "function" ||
      typeof item.onOptionSelect === "function" || typeof item.selectItem === "function" ||
      typeof item.completeMethod === "function";
    return Boolean(hasOptions && hasValue);
  }

  function matchOption(component, monthName) {
    const raw = component.options || component._options || component.filteredOptions || component.suggestions || [];
    const list = Array.isArray(raw) ? raw : (raw.data || []);
    const wanted = norm(monthName);
    const monthIndex = MONTHS.findIndex((name) => norm(name) === wanted) + 1;

    return list.find((option) => {
      if (option == null) return false;
      if (typeof option === "string" || typeof option === "number") {
        return norm(option) === wanted || Number(option) === monthIndex;
      }
      const label = option.label ?? option.name ?? option.nome ?? option.value ?? option.mes;
      return norm(label) === wanted || Number(option.value) === monthIndex || Number(option.mes) === monthIndex;
    }) || null;
  }

  function optionValue(option, monthName) {
    if (option == null) return monthName;
    if (typeof option === "string" || typeof option === "number") return option;
    return option.value ?? option.label ?? option.mes ?? monthName;
  }

  function findMonthOption(monthName) {
    return [...document.querySelectorAll([
      ".ui-autocomplete-list-item",
      ".ui-autocomplete-items li",
      ".p-autocomplete-item",
      ".p-autocomplete-option",
      ".ui-dropdown-item",
      ".ui-dropdown-items li",
      ".p-select-option",
      ".p-dropdown-item",
      ".p-select-overlay li",
      ".p-dropdown-panel li",
      "mat-option",
      "[role='option']",
      "li"
    ].join(", "))].find((el) => {
      if (!visible(el)) return false;
      if (el.closest(".p-datepicker, table, [class*='calendar']")) return false;
      return isMonthText(el.innerText || "", monthName);
    }) || null;
  }

  async function waitForMonthOption(monthName) {
    for (let step = 0; step < 12; step += 1) {
      const option = findMonthOption(monthName);
      if (option) return option;
      await sleep(150);
    }
    return null;
  }

  function isMonthText(text, monthName) {
    const value = norm(text);
    const wanted = norm(monthName);
    if (!value || !wanted) return false;
    if (value === wanted) return true;
    if (value.startsWith(`${wanted} `) || value.startsWith(`${wanted}/`)) return true;
    return value.length < 24 && value.includes(wanted);
  }

  function dismissError() {
    const button = [...document.querySelectorAll("button")].find((el) => {
      return norm(el.innerText || "") === "ok";
    });
    if (button) button.click();
  }

  function monthSelected(modal, monthName, year, month) {
    if (!modal) return false;
    if (calendarHeading(modal) === monthName) {
      const expected = expectedLastDay(year, month);
      const last = lastGridDay(modal);
      if (!expected || !last) return true;
      return last === expected;
    }
    return false;
  }

  function expectedLastDay(year, month) {
    if (!year || !month) return 0;
    return new Date(year, month, 0).getDate();
  }

  function calendarHeading(modal) {
    const nodes = [...modal.querySelectorAll("*")].filter((el) => {
      if (el.tagName === "INPUT" || el.tagName === "SELECT" || el.tagName === "BUTTON") return false;
      if (!visible(el)) return false;
      if (el.closest(".ui-autocomplete-panel, .ui-autocomplete-items, [role='listbox']")) return false;
      const text = (el.innerText || "").trim();
      return MONTHS.includes(text);
    });
    const leaves = nodes.filter((el) => !nodes.some((other) => other !== el && el.contains(other)));
    const outside = leaves.filter((el) => !el.closest("p-autocomplete"));
    const chosen = outside[outside.length - 1] || leaves[leaves.length - 1];
    return chosen ? (chosen.innerText || "").trim() : "";
  }

  function lastGridDay(modal) {
    const nums = [...modal.querySelectorAll("button, span, div, td, a")].map((el) => {
      const text = (el.innerText || "").trim();
      if (!/^\d{1,2}$/.test(text)) return 0;
      const box = el.getBoundingClientRect();
      if (box.width < 18 || box.width > 90 || box.height < 14 || box.height > 90) return 0;
      return Number(text);
    }).filter((n) => n >= 1 && n <= 31);
    return nums.length ? Math.max(...nums) : 0;
  }

  function clickDay(day) {
    const modal = calendarModal() || document;
    const labels = [String(day).padStart(2, "0"), String(day)];
    const cells = [...modal.querySelectorAll("button, td, span, div, a")].filter((el) => {
      if (el.disabled || el.getAttribute("aria-disabled") === "true") return false;
      if (/disabled|inativ|fechar/i.test(`${el.className || ""} ${el.innerText || ""}`)) return false;
      const text = (el.innerText || "").trim();
      if (!labels.includes(text)) return false;
      if (!visible(el)) return false;
      const box = el.getBoundingClientRect();
      return box.width >= 18 && box.width <= 90 && box.height >= 14 && box.height <= 90;
    });
    const leaves = cells.filter((el) => {
      return ![...el.children].some((child) => labels.includes((child.innerText || "").trim()));
    });
    const target = leaves[0];
    if (!target) return false;
    target.click();
    return true;
  }

  function debugMonth(modal, trigger, cmp, auto) {
    const tags = [
      "p-autocomplete", "p-dropdown", "p-select", ".ui-autocomplete", ".ui-dropdown",
      "input.ui-inputtext", "select", "[role='combobox']"
    ];
    const found = tags.filter((sel) => modal.querySelector(sel)).join(",");
    const cls = trigger ? `${trigger.tagName}.${String(trigger.className || "")}`.slice(0, 80) : "none";
    const value = trigger?.value || trigger?.innerText || "";
    const ctx = auto?.__ngContext__;
    const ctxKind = Array.isArray(ctx) ? `arr${ctx.length}` : (ctx ? typeof ctx : "no");
    const cmpName = cmp?.constructor?.name || "none";
    const valType = cmp ? typeof cmp.value : "no";
    const field = cmp?.field || "";
    const sugg = Array.isArray(cmp?.suggestions) ? cmp.suggestions.length : 0;
    const heading = calendarHeading(modal);
    const proto = cmp
      ? Object.getOwnPropertyNames(Object.getPrototypeOf(cmp)).filter((name) => {
        return /select|change|model|drop|complete|input/i.test(name);
      }).join(",")
      : "";
    const onCh = cmp ? typeof cmp.onModelChange : "no";
    const cmpVal = cmp ? String(cmp.value).slice(0, 20) : "";
    return `grid=${heading || "?"}; val=${String(value).slice(0, 20)}; cmp=${cmpName}; cmpVal=${cmpVal}; valType=${valType}; sugg=${sugg}; onCh=${onCh}; ctx=${ctxKind}; fn=${proto.slice(0, 80)}; hosts=${found || "nenhum"}`;
  }

  function visible(el) {
    if (!el || el.nodeType !== 1) return false;
    const style = window.getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return false;
    const box = el.getBoundingClientRect();
    return box.width > 0 && box.height > 0;
  }

  function norm(value) {
    return String(value || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, " ")
      .trim();
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
