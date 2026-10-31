function cardCodeFromText(text) {
  const compact = (text || "").toUpperCase().replace(/[^A-Z0-9]/g, "")
  const match = compact.match(/M(\d{6})(?:A(\d+))?/)
  if (!match) return null
  return { pin: match[1], studentId: match[2] || "", token: match[0] }
}

function tokenFromText(text) {
  const raw = (text || "").trim()
  if (!raw) return ""

  const card = cardCodeFromText(raw)
  if (card) return card.token

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
  const card = cardCodeFromText(token)
  if (card?.studentId) return card.studentId
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
  const card = cardCodeFromText(token)
  if (card?.studentId) {
    const base = window.location.pathname.replace(/\/a\/\d+.*$/, "")
    if (base.startsWith("/g/")) {
      window.location.href = `${base}/a/${card.studentId}`
      return
    }
    window.location.href = `/c/${card.pin}`
    return
  }
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

function decodeJsQr(jsQR, image) {
  if (!jsQR || !image) return ""
  try {
    return jsQR(image.data, image.width, image.height, { inversionAttempts: "attemptBoth" })?.data || ""
  } catch (_error) {
    return ""
  }
}

function grabRegion(video, canvas, left, top, width, height) {
  const vw = video.videoWidth
  const vh = video.videoHeight
  if (!vw || !vh) return null

  const sx = Math.floor(vw * left)
  const sy = Math.floor(vh * top)
  const sw = Math.max(1, Math.floor(vw * width))
  const sh = Math.max(1, Math.floor(vh * height))
  const outW = Math.min(800, Math.max(320, sw))
  const outH = Math.max(1, Math.round(outW * (sh / sw)))
  canvas.width = outW
  canvas.height = outH
  const context = canvas.getContext("2d", { willReadFrequently: true })
  context.imageSmoothingEnabled = false
  context.drawImage(video, sx, sy, sw, sh, 0, 0, outW, outH)
  return context.getImageData(0, 0, outW, outH)
}

async function readRaw(video, canvas, detector, jsQR) {
  let raw = ""
  if (detector) {
    try {
      const frame = grabRegion(video, canvas, 0, 0, 1, 1)
      if (frame) {
        const bitmap = await createImageBitmap(frame)
        const codes = await detector.detect(bitmap)
        raw = codes[0]?.rawValue || ""
        bitmap.close?.()
      }
    } catch (_error) {
      try {
        const codes = await detector.detect(video)
        raw = codes[0]?.rawValue || ""
      } catch (_ignored) {}
    }
  }
  if (raw) return raw

  const regions = [
    [0, 0, 1, 1],
    [0, 0, 0.5, 1],
    [0, 0, 0.35, 0.7],
    [0, 0.1, 0.45, 0.7],
    [0.05, 0.2, 0.4, 0.55],
    [0.15, 0.15, 0.7, 0.7],
    [0.25, 0.62, 0.5, 0.38],
    [0.2, 0.7, 0.6, 0.28]
  ]
  for (const region of regions) {
    raw = decodeJsQr(jsQR, grabRegion(video, canvas, ...region))
    if (raw) return raw
  }
  return ""
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
    setBanner(root, "Procurando o QR do aluno no cartão…", "wait")
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
    if (locked || root.dataset.qrLocked) return
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
      const raw = await readRaw(video, canvas, detector, jsQR)
      const parsed = cardCodeFromText(raw)
      const expectedPin = root.getAttribute("data-correction-pin") || ""
      if (parsed?.pin && expectedPin && parsed.pin !== expectedPin) {
        hits = 0
        lastToken = ""
        setBanner(root, "Este cartão é de outra prova. Use o código da tela do computador.", "warn")
        requestAnimationFrame(tick)
        return
      }
      const token = tokenFromText(raw)
      if (!token) {
        hits = 0
        lastToken = ""
        requestAnimationFrame(tick)
        return
      }

      const scannedStudent = studentIdFromToken(token)
      if (!scannedStudent) {
        hits = 0
        lastToken = ""
        setBanner(root, "Esse QR abre o site. Aponte para o QR grande do cartão do aluno.", "wait")
        requestAnimationFrame(tick)
        return
      }

      hits = token === lastToken ? hits + 1 : 1
      lastToken = token
      const name = studentName(scannedStudent)
      if (hits === 1) {
        setBanner(root, name ? `É ${name}. Capturando o cartão…` : "QR do aluno lido. Capturando…", "ok")
      }

      if (grade && scannedStudent) {
        locked = true
        root.dataset.qrLocked = "true"
        setBanner(root, name ? `Capturando o cartão de ${name}…` : "Capturando o cartão…", "wait")
        const stream = video.srcObject
        const sent = await sendCard(root, scannedStudent, canvas).catch(() => false)
        if (!sent) {
          locked = false
          delete root.dataset.qrLocked
          hits = 0
          setBanner(root, "Não consegui corrigir. Aproxime o QR grande do cartão.", "warn")
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

function fileImageData(file) {
  return new Promise((resolve, reject) => {
    const image = new Image()
    const url = URL.createObjectURL(file)
    image.onload = () => {
      const canvas = document.createElement("canvas")
      const maxSide = 1600
      const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight))
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale))
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale))
      const context = canvas.getContext("2d", { willReadFrequently: true })
      context.drawImage(image, 0, 0, canvas.width, canvas.height)
      URL.revokeObjectURL(url)
      resolve(context.getImageData(0, 0, canvas.width, canvas.height))
    }
    image.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error("foto"))
    }
    image.src = url
  })
}

function bindFileCapture(root) {
  const input = root.querySelector("[data-qr-file]")
  if (!input) return

  input.addEventListener("change", async () => {
    const file = input.files && input.files[0]
    if (!file) return

    const form = input.closest("form")
    const knownStudent = root.getAttribute("data-student-id") || ""
    if (form && root.hasAttribute("data-qr-grade") && knownStudent) {
      let hidden = form.querySelector('input[name="student_id"]')
      if (!hidden) {
        hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "student_id"
        form.appendChild(hidden)
      }
      hidden.value = knownStudent
      setBanner(root, "Enviando o cartão…", "wait")
      form.submit()
      return
    }

    setBanner(root, "Lendo o QR da foto…", "wait")

    let token = ""
    try {
      const jsQR = await loadJsQr().catch(() => window.jsQR)
      if (jsQR) {
        const image = await fileImageData(file)
        token = tokenFromText(decodeJsQr(jsQR, image))
      }
    } catch (_error) {}

    const studentId = studentIdFromToken(token) || knownStudent
    if (form && root.hasAttribute("data-qr-grade") && studentId) {
      let hidden = form.querySelector('input[name="student_id"]')
      if (!hidden) {
        hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "student_id"
        form.appendChild(hidden)
      }
      hidden.value = studentId
      form.submit()
      return
    }

    if (token) {
      openToken(token)
      return
    }

    setBanner(root, "Não li o QR nesta foto. Enquadre o cartão inteiro (QR + bolhas).", "warn")
    input.value = ""
  })
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

function bindCaptureNow(root) {
  const button = root.querySelector("[data-qr-capture]")
  if (!button) return

  button.addEventListener("click", async () => {
    const studentId = root.getAttribute("data-student-id") || ""
    if (!studentId) {
      setBanner(root, "Escolha o aluno na lista antes de fotografar o cartão.", "warn")
      return
    }
    if (root.dataset.qrLocked) return

    const video = root.querySelector("[data-qr-video]")
    if (!root.dataset.qrLive) {
      await startScanner(root)
    }
    if (!video?.srcObject) {
      setBanner(root, "A câmera ainda não ligou. Toque de novo em Corrigir agora.", "warn")
      return
    }

    root.dataset.qrLocked = "true"
    const canvas = document.createElement("canvas")
    const sent = await sendCard(root, studentId, canvas).catch(() => false)
    if (!sent) {
      delete root.dataset.qrLocked
      setBanner(root, "Não consegui corrigir. Enquadre o cartão inteiro e toque de novo.", "warn")
      return
    }
    const stream = video.srcObject
    if (stream) stream.getTracks().forEach((track) => track.stop())
  })
}

function bindScanner(root) {
  if (!root || root.dataset.qrBound) return
  root.dataset.qrBound = "true"
  bindPaste(root)
  bindFileCapture(root)
  bindCaptureNow(root)

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
    const capture = root.querySelector("[data-qr-capture]")
    if (capture) capture.hidden = true
    return
  }

  if (phone && grade) {
    if (start) start.hidden = true
    setBanner(root, "Aponte para o QR grande do cartão. O Maestro reconhece o aluno sozinho.", "wait")
    startScanner(root)
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
