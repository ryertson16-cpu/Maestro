function scrollLiraThread() {
  const thread = document.querySelector("[data-lira-thread]");

  if (!thread) {
    return;
  }

  thread.scrollTop = thread.scrollHeight;
}

function liraForm() {
  return document.querySelector("[data-lira-composer]");
}

function liraInput() {
  return document.getElementById("lira-body");
}

function submitLiraPrompt(text) {
  const form = liraForm();
  const input = liraInput();

  if (!form || !input || !text) {
    return;
  }

  input.value = text;
  form.requestSubmit();
}

document.addEventListener("turbo:load", scrollLiraThread);
document.addEventListener("turbo:render", scrollLiraThread);
document.addEventListener("turbo:frame-load", scrollLiraThread);
document.addEventListener("turbo:submit-end", scrollLiraThread);

document.addEventListener("click", function (event) {
  const chip = event.target.closest("[data-lira-prompt]");

  if (chip) {
    event.preventDefault();
    submitLiraPrompt(chip.dataset.liraPrompt);
    return;
  }

  const copy = event.target.closest("[data-lira-copy]");

  if (copy) {
    event.preventDefault();
    copyLiraMessage(copy);
    return;
  }

  const mic = event.target.closest("[data-lira-mic]");

  if (!mic) {
    return;
  }

  event.preventDefault();
  startLiraDictation(mic);
});

function copyLiraMessage(button) {
  const root = button.closest("[data-lira-copy-root]") || button.closest(".lira-bubble");
  const body = root?.querySelector("[data-lira-copy-body]");

  if (!body || !navigator.clipboard) {
    return;
  }

  let text = (body.value || body.innerText || "").trim();
  const marker = "Mensagem para colar no grupo";
  const at = text.indexOf(marker);

  if (at >= 0) {
    text = text.slice(at).replace(/Eu não envio no WhatsApp[\s\S]*$/u, "").trim();
  }

  navigator.clipboard.writeText(text).then(function () {
    const previous = button.textContent;
    button.textContent = "Copiado";
    window.setTimeout(function () {
      button.textContent = previous;
    }, 1800);
  });
}

document.addEventListener("keydown", function (event) {
  if (event.key !== "Enter" || event.shiftKey) {
    return;
  }

  if (event.target.id !== "lira-body") {
    return;
  }

  event.preventDefault();
  event.target.form?.requestSubmit();
});

function startLiraDictation(button) {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;

  if (!Recognition) {
    window.alert("Este navegador não reconhece voz. Use Chrome ou Edge, ou escreva para o Maestro.");
    return;
  }

  const recognition = new Recognition();
  recognition.lang = "pt-BR";
  recognition.interimResults = false;
  recognition.maxAlternatives = 1;

  button.classList.add("is-listening");
  button.setAttribute("aria-pressed", "true");

  recognition.addEventListener("result", function (event) {
    const transcript = Array.from(event.results)
      .map((result) => result[0]?.transcript)
      .join(" ")
      .trim();

    if (transcript) {
      submitLiraPrompt(transcript);
    }
  });

  recognition.addEventListener("end", function () {
    button.classList.remove("is-listening");
    button.removeAttribute("aria-pressed");
  });

  recognition.addEventListener("error", function () {
    button.classList.remove("is-listening");
    button.removeAttribute("aria-pressed");
  });

  recognition.start();
}
