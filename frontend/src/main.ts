import './style.css'

const app : any = document.querySelector("#app");

async function loadItems() {
  const res = await fetch("http://localhost:3001/items");
  const items = await res.json();

  app.innerHTML = `
    <h1>Items</h1>
    <input id="name" placeholder="Item nost:5173/
  ➜  Network: use --host to expose
  ➜  press h + enter to show helpame"/>
    <button id="add">Add</button>
    <ul>
      ${items.map((i: any) => `<li>${i.name}</li>`).join("")}
    </ul>
  `;

  (document.getElementById("add") as any).onclick = async () => {
    const name: any = (document.getElementById("name") as any).value;
    await fetch("http://localhost:3001/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name })
    });
    loadItems();
  };
}

loadItems();
