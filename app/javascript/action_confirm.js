const DEFAULT_MESSAGE = "Deseja confirmar esta ação?"
const CANCELLED_TITLE = "Ação cancelada"
const CANCELLED_MESSAGE = "A ação foi cancelada."

let pending = null

function dialog() {
  return document.getElementById("action-confirm")
}

function dialogCopy() {
  return document.querySelector("[data-action-confirm-copy]")
}

function showDenied() {
  window.setTimeout(() => {
    window.MaestroToast?.show({
      kind: "error",
      title: CANCELLED_TITLE,
      message: CANCELLED_MESSAGE
    })
  }, 0)
}

function askConfirm(message) {
  const node = dialog()
  if (!node || typeof node.showModal !== "function") {
    return Promise.resolve(window.confirm(message || DEFAULT_MESSAGE))
  }

  if (pending) pending.resolve(false)

  const copy = dialogCopy()
  if (copy) copy.textContent = message || DEFAULT_MESSAGE

  return new Promise((resolve) => {
    pending = { resolve }
    if (!node.open) node.showModal()
  })
}

function settle(accepted) {
  const node = dialog()
  if (node?.open) node.close()

  const current = pending
  pending = null
  current?.resolve(Boolean(accepted))
}

function formMethod(form) {
  const override = form.querySelector("input[name='_method']")?.value
  return (override || form.getAttribute("method") || form.method || "get").toLowerCase()
}

function isGetForm(form) {
  return formMethod(form) === "get"
}

function isLogoutForm(form) {
  const action = `${form.getAttribute("action") || ""} ${form.action || ""}`.toLowerCase()
  return action.includes("sign_out") || action.includes("logout")
}

function confirmMessageFor(element, form) {
  return (
    element?.getAttribute("data-confirm-message") ||
    element?.dataset?.confirmMessage ||
    form?.getAttribute("data-confirm-message") ||
    form?.dataset?.confirmMessage ||
    element?.getAttribute("data-turbo-confirm") ||
    element?.dataset?.turboConfirm ||
    form?.getAttribute("data-turbo-confirm") ||
    form?.dataset?.turboConfirm ||
    DEFAULT_MESSAGE
  )
}

function shouldSkipElement(element) {
  if (!element || !(element instanceof HTMLElement)) return true
  if (document.querySelector(".auth-main")) return true
  if (element.closest("dialog")) return true
  if (element.closest("[data-command-palette]")) return true
  if (element.closest(".toast")) return true
  if (element.matches("[data-skip-confirm], [data-fill-today], [data-theme-toggle], [data-command-palette-open], [data-calendar-day], [data-generate-open], [data-calendar-pdf-open], [data-generate-cancel], [data-calendar-confirm-create], [data-attendance-mark-all]")) {
    return true
  }
  if (element.closest("[data-skip-confirm], [data-classroom-switch]")) return true
  if (element.classList.contains("toast-dismiss")) return true
  if (element.classList.contains("monitoring-filter-chip")) return true
  if (element.classList.contains("header-search")) return true
  if (element.getAttribute("role") === "switch") return true
  if (element.dataset.action === "clipboard#copy") return true
  if (element.dataset.confirmed === "true") return true
  return false
}

function isSiageExportLink(element) {
  const href = (element.getAttribute("href") || "").toLowerCase()
  if (!href.includes("siage")) return false
  if (href.includes("help") || href.includes("livro") || href.includes("ledger")) return false
  return href.includes("export") || href.includes("/siage/")
}

function isMutatingLink(element) {
  if (!element.matches("a")) return false
  const method = (element.dataset.turboMethod || "get").toLowerCase()
  if (["delete", "post", "patch", "put"].includes(method)) return true
  if (element.hasAttribute("data-turbo-confirm") || element.dataset.turboConfirm) return true
  if (element.hasAttribute("data-confirm-message") || element.dataset.confirmMessage) return true
  return isSiageExportLink(element)
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
}

function submitAs(method, url) {
  const form = document.createElement("form")
  form.method = "post"
  form.action = url
  form.hidden = true
  form.dataset.skipConfirm = "true"

  const methodField = document.createElement("input")
  methodField.type = "hidden"
  methodField.name = "_method"
  methodField.value = method
  form.appendChild(methodField)

  const token = csrfToken()
  if (token) {
    const csrfField = document.createElement("input")
    csrfField.type = "hidden"
    csrfField.name = "authenticity_token"
    csrfField.value = token
    form.appendChild(csrfField)
  }

  document.body.appendChild(form)
  if (typeof form.requestSubmit === "function") {
    form.requestSubmit()
  } else {
    form.submit()
  }
}

async function confirmThen(element, proceed) {
  const accepted = await askConfirm(confirmMessageFor(element, element.closest("form")))
  if (!accepted) {
    showDenied()
    return
  }
  window.__maestroActionAccepted = true
  proceed()
}

function wireTurboConfirm() {
  const confirmFn = async (message) => {
    if (window.__maestroActionAccepted) {
      window.__maestroActionAccepted = false
      return true
    }

    const accepted = await askConfirm(message || DEFAULT_MESSAGE)
    if (!accepted) showDenied()
    return accepted
  }

  if (window.Turbo?.session) {
    window.Turbo.config = window.Turbo.config || {}
    window.Turbo.config.forms = window.Turbo.config.forms || {}
    window.Turbo.config.forms.confirm = confirmFn
  }

  if (typeof window.Turbo?.setConfirmMethod === "function") {
    window.Turbo.setConfirmMethod(confirmFn)
  }
}

document.addEventListener("click", (event) => {
  const node = dialog()
  if (!node) return

  if (event.target.closest("[data-action-confirm-yes]")) {
    event.preventDefault()
    settle(true)
    return
  }

  if (event.target.closest("[data-action-confirm-no]")) {
    event.preventDefault()
    settle(false)
  }
})

document.addEventListener("cancel", (event) => {
  if (event.target === dialog()) settle(false)
})

document.addEventListener(
  "submit",
  (event) => {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    if (isGetForm(form)) return
    if (isLogoutForm(form)) return
    if (form.dataset.confirmed === "true") {
      delete form.dataset.confirmed
      return
    }
    if (form.closest("dialog")) return
    if (event.submitter?.closest("dialog")) return
    if (shouldSkipElement(form)) return
    if (event.submitter && shouldSkipElement(event.submitter)) return

    event.preventDefault()
    event.stopPropagation()

    confirmThen(event.submitter || form, () => {
      form.dataset.confirmed = "true"
      if (typeof form.requestSubmit === "function") {
        form.requestSubmit(event.submitter)
      } else {
        form.submit()
      }
    })
  },
  true
)

document.addEventListener(
  "click",
  (event) => {
    if (event.button !== 0) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    const element = event.target.closest("a[data-turbo-method], a[data-turbo-confirm], a[href]")
    if (!element) return
    if (shouldSkipElement(element)) return
    if (!isMutatingLink(element)) return

    event.preventDefault()
    event.stopImmediatePropagation()
    confirmThen(element, () => {
      const method = (element.dataset.turboMethod || "get").toLowerCase()
      if (["delete", "post", "patch", "put"].includes(method)) {
        window.setTimeout(() => submitAs(method, element.href), 0)
        return
      }

      element.dataset.confirmed = "true"
      element.click()
      window.setTimeout(() => {
        delete element.dataset.confirmed
      }, 0)
    })
  },
  true
)

document.addEventListener("turbo:load", wireTurboConfirm)
document.addEventListener("DOMContentLoaded", wireTurboConfirm)

window.MaestroActionConfirm = { ask: askConfirm, denied: showDenied }
