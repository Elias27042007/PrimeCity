const app = document.getElementById('app');
const itemsEl = document.getElementById('items');
const weightEl = document.getElementById('weight');
const closeBtn = document.getElementById('closeBtn');
const nearbyPlayersEl = document.getElementById('nearbyPlayers');
const refreshNearbyBtn = document.getElementById('refreshNearbyBtn');

const state = {
  inventory: { items: [], currentWeight: 0, maxWeight: 0 },
  nearbyPlayers: []
};

const closeInventory = async () => {
  await post('inventory:close');
};

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });
  return response.json();
};

const renderNearbyPlayers = () => {
  const players = state.nearbyPlayers || [];
  nearbyPlayersEl.innerHTML = '';

  if (!players.length) {
    const option = document.createElement('option');
    option.value = '';
    option.textContent = 'Kein Spieler in der Nähe';
    nearbyPlayersEl.appendChild(option);
    nearbyPlayersEl.disabled = true;
    return;
  }

  nearbyPlayersEl.disabled = false;
  players.forEach((player) => {
    const option = document.createElement('option');
    option.value = String(player.id);
    option.textContent = `${player.name} (${player.id}) - ${player.distance}m`;
    nearbyPlayersEl.appendChild(option);
  });
};

const refreshNearbyPlayers = async () => {
  try {
    const result = await post('inventory:getNearbyPlayers');
    state.nearbyPlayers = Array.isArray(result?.players) ? result.players : [];
  } catch (_err) {
    state.nearbyPlayers = [];
  }
  renderNearbyPlayers();
};

const getSelectedTargetId = () => Number(nearbyPlayersEl.value || 0);

const createIcon = (item) => {
  const img = document.createElement('img');
  img.className = 'icon';
  const localSrc = String(item.icon || '').trim();
  const fallbackSrc = 'icons/items/_placeholder.png';
  const candidates = [localSrc, fallbackSrc].filter(Boolean);
  let index = 0;

  const applyCandidate = () => {
    if (index >= candidates.length) {
      return;
    }
    img.src = candidates[index];
    index += 1;
  };

  img.addEventListener('error', applyCandidate);
  applyCandidate();
  return img;
};

const render = () => {
  const data = state.inventory || { items: [] };
  weightEl.textContent = `${Number(data.currentWeight || 0)} / ${Number(data.maxWeight || 0)} g`;
  itemsEl.innerHTML = '';

  if (!data.items?.length) {
    itemsEl.innerHTML = '<div class="item"><h3>Leer</h3><p>Kein Item vorhanden.</p></div>';
    return;
  }

  data.items.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'item';

    const head = document.createElement('div');
    head.className = 'itemHead';
    const icon = createIcon(item);
    const titleWrap = document.createElement('div');
    titleWrap.className = 'titleWrap';
    titleWrap.innerHTML = `
      <h3>${item.label} x${item.quantity}</h3>
      <p>${item.description || 'Kein Beschreibungstext'}</p>
    `;
    head.appendChild(icon);
    head.appendChild(titleWrap);
    card.appendChild(head);

    const actions = document.createElement('div');
    actions.className = 'actions';
    const qtyInput = document.createElement('input');
    qtyInput.type = 'number';
    qtyInput.min = '1';
    qtyInput.max = String(Math.max(1, Number(item.quantity || 1)));
    qtyInput.value = '1';
    qtyInput.className = 'qty';
    actions.appendChild(qtyInput);

    if (item.usable) {
      const useBtn = document.createElement('button');
      useBtn.textContent = 'Benutzen';
      useBtn.addEventListener('click', async () => {
        const quantity = Math.max(1, Math.floor(Number(qtyInput.value || 1)));
        await post('inventory:useItem', { itemName: item.itemName, quantity });
      });
      actions.appendChild(useBtn);
    }

    const giveBtn = document.createElement('button');
    giveBtn.textContent = 'Geben';
    giveBtn.addEventListener('click', async () => {
      const quantity = Math.max(1, Math.floor(Number(qtyInput.value || 1)));
      const targetId = getSelectedTargetId();
      if (!targetId) {
        return;
      }
      await post('inventory:giveItem', {
        itemName: item.itemName,
        quantity,
        targetId
      });
      await refreshNearbyPlayers();
    });
    actions.appendChild(giveBtn);

    const dropBtn = document.createElement('button');
    dropBtn.textContent = 'Droppen';
    dropBtn.className = 'danger';
    dropBtn.addEventListener('click', async () => {
      const quantity = Math.max(1, Math.floor(Number(qtyInput.value || 1)));
      await post('inventory:dropItem', { itemName: item.itemName, quantity });
    });
    actions.appendChild(dropBtn);

    card.appendChild(actions);
    itemsEl.appendChild(card);
  });
};

window.addEventListener('message', async (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    app.classList.remove('hidden');
    state.inventory = data || { items: [] };
    render();
    await refreshNearbyPlayers();
  }
  if (action === 'update') {
    state.inventory = data || { items: [] };
    render();
  }
  if (action === 'close') {
    app.classList.add('hidden');
  }
});

closeBtn.addEventListener('click', async () => {
  await closeInventory();
});

refreshNearbyBtn.addEventListener('click', async () => {
  await refreshNearbyPlayers();
});

window.addEventListener('keydown', async (event) => {
  if (event.key !== 'Escape') {
    return;
  }
  if (app.classList.contains('hidden')) {
    return;
  }
  event.preventDefault();
  await closeInventory();
});
