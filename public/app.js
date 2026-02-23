const API = "/api/tasks";
const listEl = document.getElementById("task-list");
const formEl = document.getElementById("task-form");
const inputEl = document.getElementById("task-input");

async function loadTasks() {
  const res = await fetch(API);
  const data = await res.json();
  renderTasks(data);
}

function renderTasks(tasks) {
  listEl.innerHTML = "";
  tasks.forEach(t => {
    const li = document.createElement("li");
    li.className = "task" + (t.done ? " done" : "");
    const span = document.createElement("span");
    span.textContent = t.title;

    const toggleBtn = document.createElement("button");
    toggleBtn.textContent = t.done ? "Undo" : "Done";
    toggleBtn.onclick = () => toggleTask(t.id, !t.done);

    const delBtn = document.createElement("button");
    delBtn.textContent = "X";
    delBtn.onclick = () => deleteTask(t.id);

    li.appendChild(span);
    li.appendChild(toggleBtn);
    li.appendChild(delBtn);
    listEl.appendChild(li);
  });
}

async function addTask(title) {
  await fetch(API, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title })
  });
  await loadTasks();
}

async function toggleTask(id, done) {
  await fetch(`${API}/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ done })
  });
  await loadTasks();
}

async function deleteTask(id) {
  await fetch(`${API}/${id}`, { method: "DELETE" });
  await loadTasks();
}

formEl.addEventListener("submit", e => {
  e.preventDefault();
  const title = inputEl.value.trim();
  if (!title) return;
  addTask(title);
  inputEl.value = "";
});

loadTasks();
