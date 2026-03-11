import './style.css'

const app: any = document.querySelector("#app");
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

async function loadItems() {
  const res = await fetch(`${API_URL}/items`);
  const items = await res.json();

  app.innerHTML = `
    <h1>Items</h1>
    <input id="name" placeholder="Random word"/>
    <button id="add">Add</button>
    <ul>
      ${items.map((i: any) => `<li>${i.name}</li>`).join("")}
    </ul>
  `;

  (document.getElementById("add") as any).onclick = async () => {
    const name: any = (document.getElementById("name") as any).value;
    await fetch(`${API_URL}/items`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name })
    });
    loadItems();
  };
}

loadItems();
