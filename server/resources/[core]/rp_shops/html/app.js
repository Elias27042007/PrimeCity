const app = document.getElementById('app');
const closeBtn = document.getElementById('closeBtn');
const itemsEl = document.getElementById('items');
const shopTitle = document.getElementById('shopTitle');
const cashEl = document.getElementById('cash');
const bankEl = document.getElementById('bank');

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });
  return response.json();
};

const fmt = (v) => `${Number(v || 0).toLocaleString('de-DE')}$`;

const render = (data) => {
  shopTitle.textContent = data.shopLabel || 'Shop';
  cashEl.textContent = fmt(data.cash);
  bankEl.textContent = fmt(data.bank);
  itemsEl.innerHTML = '';

  (data.items || []).forEach((item) => {
    const el = document.createElement('div');
    el.className = 'item';
    el.innerHTML = `
      <strong>${item.label}</strong>
      <span>${fmt(item.price)} (${item.currency})</span>
      <div class="row">
        <input type="number" min="1" value="1" />
        <select>
          <option value="cash">Bargeld</option>
          <option value="bank">Bank</option>
        </select>
      </div>
      <button>Kaufen</button>
    `;

    const qty = el.querySelector('input');
    const pay = el.querySelector('select');
    const btn = el.querySelector('button');

    pay.value = item.currency === 'bank' ? 'bank' : 'cash';

    btn.addEventListener('click', async () => {
      await post('shop:buy', {
        itemName: item.itemName,
        quantity: Number(qty.value || 1),
        payType: pay.value
      });
    });

    itemsEl.appendChild(el);
  });
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    app.classList.remove('hidden');
    render(data || {});
  }
  if (action === 'close') {
    app.classList.add('hidden');
  }
});

closeBtn.addEventListener('click', async () => {
  await post('shop:close');
});
