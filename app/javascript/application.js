// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "toasts"
import "action_confirm"
import "nav_menu"
import "classroom_switch"
import "student_profile"
import "attendance_grid"
import "lesson_form"
import "attendance_call"
import "auth"
import "theme"
import "command_palette"
import "school_calendar"
import "lira_chat"
import "maestro_quick"
import "attendance_offline"

document.addEventListener("click", function (event) {
  const button = event.target.closest("[data-fill-today]");

  if (!button) {
    return;
  }

  const input = document.getElementById(button.dataset.target);

  if (input) {
    input.value = button.dataset.today;
  }
});

document.addEventListener("change", function (event) {
  if (!event.target.matches(".attendance-status-select")) {
    return;
  }

  const select = event.target;
  const cell = select.closest(".attendance-status-cell");

  if (!cell) {
    return;
  }

  cell.classList.remove(
    "status-present",
    "status-absent",
    "status-justified",
    "status-late"
  );

  cell.classList.add(`status-${select.value}`);
});