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

async function startScanner(root) {
  const video = root.querySelector("[data-qr-video]")
  const status = root.querySelector("[data-qr-status]")
  if (!video) return

  if (!window.isSecureContext && window.location.hostname !== "localhost") {
    if (status) status.textContent = "A câmera precisa de HTTPS ou localhost."
    return
  }

  if (!navigator.mediaDevices?.getUserMedia) {
    if (status) status.textContent = "Este navegador não libera a câmera. Cole o token abaixo."
    return
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: "environment" } },
      audio: false
    })
    video.srcObject = stream
    await video.play()
    if (status) status.textContent = "Enquadre o QR da folha."
  } catch (_error) {
    if (status) status.textContent = "Não foi possível abrir a câmera. Cole o token da montagem."
    return
  }

  if (typeof BarcodeDetector !== "function") {
    if (status) status.textContent = "Câmera aberta. Se o QR não for lido, cole o token."
    return
  }

  const detector = new BarcodeDetector({ formats: ["qr_code"] })
  let locked = false

  const tick = async () => {
    if (locked || video.readyState < 2) {
      requestAnimationFrame(tick)
      return
    }

    try {
      const codes = await detector.detect(video)
      const token = tokenFromText(codes[0]?.rawValue)
      if (token) {
        locked = true
        if (status) status.textContent = "QR lido. Abrindo a correção…"
        const stream = video.srcObject
        if (stream) stream.getTracks().forEach((track) => track.stop())
        openToken(token)
        return
      }
    } catch (_error) {}

    requestAnimationFrame(tick)
  }

  requestAnimationFrame(tick)
}

document.addEventListener("turbo:load", () => {
  const root = document.querySelector("[data-qr-scanner]")
  if (root) startScanner(root)
})
