const express = require("express");
const cors = require("cors");

const PORT = process.env.PORT || 3001;

const app = express();
app.use(cors());
app.use(express.json());

// Simplified: In-memory data store instead of SQLite
let items = [
  { id: 1, name: "Testing with second time." }
];
let nextId = 2;

// GET all items
app.get("/items", (req, res) => {
  res.json(items);
});

// POST a new item
app.post("/items", (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: "Name is required" });
  }

  const newItem = { id: nextId++, name };
  items.push(newItem);
  
  console.log(`Added item: ${name}`);
  res.json(newItem);
});

app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
  console.log(`Note: Database is running in-memory (JS Object)`);
});
