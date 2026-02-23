const express = require("express");
const cors = require("cors");
const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static("public"));

let tasks = []; // { id, title, done, date }

app.get("/api/tasks", (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  res.json(tasks.filter(t => t.date === today));
});

app.post("/api/tasks", (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: "Title required" });
  const today = new Date().toISOString().slice(0, 10);
  const task = { id: Date.now(), title, done: false, date: today };
  tasks.push(task);
  res.status(201).json(task);
});

app.patch("/api/tasks/:id", (req, res) => {
  const id = Number(req.params.id);
  const task = tasks.find(t => t.id === id);
  if (!task) return res.status(404).json({ error: "Not found" });
  if (typeof req.body.done === "boolean") task.done = req.body.done;
  res.json(task);
});

app.delete("/api/tasks/:id", (req, res) => {
  const id = Number(req.params.id);
  tasks = tasks.filter(t => t.id !== id);
  res.status(204).end();
});

app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));
