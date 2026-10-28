function tokenFromText(text) {
  const raw = (text || "").trim()
  if (!raw) return ""

  try {
    const url = new URL(raw, window.location.origin)
    if (url.pathname.startsWith("/g/")) return url.pathname + url.search
    return url.searchParams.get("t") || url.searchParams.get("token") || ""
  } catch (_error) {
    const path = raw.match(/\/g\/[A-Za-z0-9]+(?:\/a\/\d+)?/)
    if (path) return path[0]
    const match = raw.match(/[?&]t=([^&]+)/)
    if (match) return decodeURIComponent(match[1])
    return raw
  }
}

function studentIdFromToken(token) {
  const match = (token || "").match(/\/a\/(\d+)/)
  return match ? match[1] : ""
}

function studentName(id) {
  if (!id) return ""
  const link = document.querySelector(`.correction-student[href*="/a/${id}"]`)
  if (link) return (link.getAttribute("data-student-name") || link.textContent || "").trim()
  const heading = document.querySelector(".correction-card h2")
  return heading ? heading.textContent.trim() : ""
}

function openToken(token) {
  if (!token) return
  if (token.startsWith("/g/")) {
    window.location.href = token
    return
  }
  const target = new URL(window.location.href)
  target.searchParams.set("t", token)
  window.location.href = target.toString()
}

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.getAttribute("content") : ""
}

function setBanner(root, text, kind) {
  const status = root.querySelector("[data-qr-status]")
  if (!status) return
  status.textContent = text
  status.classList.remove("is-wait", "is-ok", "is-warn")
  status.classList.add(`is-${kind || "wait"}`)
}

function loadJsQr() {
  if (window.jsQR) return Promise.resolve(window.jsQR)

  const sources = ["/vendor/jsqr.min.js", "https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.min.js"]

  return sources.reduce((chain, src) => {
    return chain.catch(() => new Promise((resolve, reject) => {
      if (window.jsQR) {
        resolve(window.jsQR)
        return
      }
      const script = document.createElement("script")
      script.src = src
      script.async = true
      script.onload = () => (window.jsQR ? resolve(window.jsQR) : reject(new Error("jsQR ausente")))
      script.onerror = () => reject(new Error("jsQR não carregou"))
      document.head.appendChild(script)
    }))
  }, Promise.reject(new Error("start")))
}

function grabFrame(video, canvas) {
  const width = video.videoWidth
  const height = video.videoHeight
  if (!width || !height) return null

  canvas.width = width
  canvas.height = height
  const context = canvas.getContext("2d", { willReadFrequently: true })
  context.drawImage(video, 0, 0, width, height)
  return context.getImageData(0, 0, width, height)
}

function frameBlob(canvas) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("frame vazio"))),
      "image/jpeg",
      0.85
    )
  })
}

async function readRaw(video, canvas, detector, jsQR) {
  let raw = ""
  if (detector) {
    try {
      const codes = await detector.detect(video)
      raw = codes[0]?.rawValue || ""
    } catch (_error) {}
  }
  if (!raw && jsQR) {
    const image = grabFrame(video, canvas)
    if (image) {
      const code = jsQR(image.data, image.width, image.height)
      raw = code?.data || ""
    }
  }
  return raw
}

async function sendCard(root, studentId, canvas) {
  const scanUrl = root.getAttribute("data-scan-url")
  if (!scanUrl || !studentId) return false

  const name = studentName(studentId)
  setBanner(root, name ? `Lendo o gabarito de ${name}…` : "QR lido. Lendo as bolhas…", "wait")

  grabFrame(root.querySelector("[data-qr-video]"), canvas)
  const blob = await frameBlob(canvas)
  const body = new FormData()
  body.append("authenticity_token", csrfToken())
  body.append("student_id", studentId)
  body.append("card", blob, "cartao.jpg")

  const response = await fetch(scanUrl, {
    method: "POST",
    body,
    credentials: "same-origin",
    redirect: "follow"
  })

  if (response.redirected || response.ok) {
    const url = response.url || ""
    if (url.includes("ok=1")) {
      setBanner(root, name ? `Gabarito de ${name} corrigido.` : "Gabarito corrigido.", "ok")
    } else if (url) {
      setBanner(root, "Não fechei a nota sozinho. Confira as letras na tela.", "warn")
    }
    window.setTimeout(() => {
      if (response.url) window.location.href = response.url
    }, 700)
    return true
  }

  setBanner(root, "Não consegui corrigir este gabarito. Enquadre de novo o cartão.", "warn")
  return false
}

async function startScanner(root) {
  const video = root.querySelector("[data-qr-video]")
  const grade = root.hasAttribute("data-qr-grade")
  const knownStudent = root.getAttribute("data-student-id") || ""
  if (!video) return

  if (!window.isSecureContext && window.location.hostname !== "localhost") {
    setBanner(root, "A câmera precisa de HTTPS. Recarregue o gabarito pelo QR da montagem.", "warn")
    return
  }

  if (!navigator.mediaDevices?.getUserMedia) {
    setBanner(root, "Este navegador não libera a câmera. Toque no nome do aluno.", "warn")
    return
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: { ideal: "environment" },
        width: { ideal: 1280 },
        height: { ideal: 720 }
      },
      audio: false
    })
    root.dataset.qrLive = "true"
    video.hidden = false
    video.srcObject = stream
    await video.play()
    setBanner(root, "Procurando o QR do aluno… aponte para o cartão.", "wait")
  } catch (_error) {
    setBanner(root, "Não foi possível abrir a câmera. Toque no nome do aluno na lista.", "warn")
    return
  }

  let detector = typeof BarcodeDetector === "function"
    ? new BarcodeDetector({ formats: ["qr_code"] })
    : null
  let jsQR = window.jsQR || null
  loadJsQr().then((lib) => { jsQR = lib }).catch(() => {})

  const canvas = document.createElement("canvas")
  let locked = false
  let lastTry = 0
  let hits = 0
  let lastToken = ""

  const tick = async (now) => {
    if (locked) return
    if (video.readyState < 2 || now - lastTry < 180) {
      requestAnimationFrame(tick)
      return
    }
    lastTry = now

    if (!detector && !jsQR) {
      jsQR = window.jsQR || null
      requestAnimationFrame(tick)
      return
    }

    try {
      const token = tokenFromText(await readRaw(video, canvas, detector, jsQR))
      if (!token) {
        hits = 0
        lastToken = ""
        requestAnimationFrame(tick)
        return
      }

      hits = token === lastToken ? hits + 1 : 1
      lastToken = token
      const scannedStudent = studentIdFromToken(token)
      const name = studentName(scannedStudent || knownStudent)
      if (hits === 1) {
        setBanner(root, name ? `QR de ${name} encontrado…` : "QR do aluno encontrado…", "wait")
      }
      if (hits < 2) {
        requestAnimationFrame(tick)
        return
      }

      const studentId = scannedStudent || knownStudent

      if (grade && studentId) {
        locked = true
        const stream = video.srcObject
        const sent = await sendCard(root, studentId, canvas).catch(() => false)
        if (!sent) {
          locked = false
          hits = 0
          setBanner(root, "Não consegui corrigir. Enquadre o cartão inteiro (QR + bolhas).", "warn")
          requestAnimationFrame(tick)
          return
        }
        if (stream) stream.getTracks().forEach((track) => track.stop())
        return
      }

      locked = true
      setBanner(root, name ? `QR lido: ${name}. Abrindo a ficha…` : "QR lido. Abrindo a ficha do aluno…", "ok")
      const stream = video.srcObject
      if (stream) stream.getTracks().forEach((track) => track.stop())
      window.setTimeout(() => openToken(token), 500)
      return
    } catch (_error) {}

    requestAnimationFrame(tick)
  }

  requestAnimationFrame(tick)
}

function bindPaste(root) {
  const paste = root.querySelector("[data-qr-paste]")
  if (!paste) return

  const submit = () => {
    const token = tokenFromText(paste.value)
    if (token) openToken(token)
  }

  paste.addEventListener("change", submit)
  paste.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault()
      submit()
    }
  })
}

function bindScanner(root) {
  if (!root || root.dataset.qrBound) return
  root.dataset.qrBound = "true"
  bindPaste(root)

  const phone = window.matchMedia("(pointer: coarse)").matches
  const start = root.querySelector("[data-qr-start]")
  const grade = root.hasAttribute("data-qr-grade")

  if (!phone) {
    setBanner(
      root,
      grade
        ? "No computador, envie a foto em Correções. No celular, a câmera avisa se o gabarito foi corrigido."
        : "No computador, use o QR desta tela. A câmera fica no celular.",
      "wait"
    )
    if (start) start.hidden = true
    return
  }

  if (start) {
    start.addEventListener("click", () => {
      start.hidden = true
      startScanner(root)
    })
    setBanner(
      root,
      grade
        ? "Toque para abrir a câmera. A tela avisa se o gabarito foi corrigido."
        : "Toque para apontar ao QR do aluno. A tela avisa quando ler.",
      "wait"
    )
    return
  }

  startScanner(root)
}

function bindAllScanners() {
  document.querySelectorAll("[data-qr-scanner]").forEach((root) => bindScanner(root))
}

document.addEventListener("turbo:load", bindAllScanners)
document.addEventListener("DOMContentLoaded", bindAllScanners)
