const app = document.getElementById('app');
const itemsEl = document.getElementById('items');
const weightEl = document.getElementById('weight');
const closeBtn = document.getElementById('closeBtn');

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });
  return response.json();
};

const render = (data) => {
  weightEl.textContent = `${Number(data.currentWeight || 0)} / ${Number(data.maxWeight || 0)} g`;
  itemsEl.innerHTML = '';

  if (!data.items?.length) {
    itemsEl.innerHTML = '<div class="item"><h3>Leer</h3><p>Kein Item vorhanden.</p></div>';
    return;
  }

  data.items.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'item';
    card.innerHTML = `
      <h3>${item.label} x${item.quantity}</h3>
      <p>${item.description || 'Kein Beschreibungstext'}</p>
      ${item.usable ? '<button>Diesen Gegenstand benutzen</button>' : ''}
    `;

    if (item.usable) {
      card.querySelector('button').addEventListener('click', async () => {
        await post('inventory:useItem', { itemName: item.itemName });
      });
    }

    itemsEl.appendChild(card);
  });
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    app.classList.remove('hidden');
    render(data || { items: [] });
  }
  if (action === 'update') {
    render(data || { items: [] });
  }
  if (action === 'close') {
    app.classList.add('hidden');
  }
});

closeBtn.addEventListener('click', async () => {
  await post('inventory:close');
});
