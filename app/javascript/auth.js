function labelForPassword(visible) {
  return visible ? "Ocultar" : "Mostrar"
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-password-toggle]")
  if (!button) return

  event.preventDefault()
  const input = document.getElementById(button.dataset.passwordToggle)
  if (!input) return

  const visible = input.type === "password"
  input.type = visible ? "text" : "password"
  button.classList.toggle("is-revealed", visible)
  button.setAttribute("aria-label", `${labelForPassword(visible)} senha`)
  if (!button.querySelector("svg")) {
    button.textContent = labelForPassword(visible)
  }
})
