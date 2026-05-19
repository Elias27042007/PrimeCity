const app = document.getElementById('app');
const itemsEl = document.getElementById('items');
const weightEl = document.getElementById('weight');
const closeBtn = document.getElementById('closeBtn');

const itemActionModal = document.getElementById('itemActionModal');
const itemActionTitle = document.getElementById('itemActionTitle');
const itemActionDescription = document.getElementById('itemActionDescription');
const itemActionQty = document.getElementById('itemActionQty');
const itemActionButtons = document.getElementById('itemActionButtons');
const itemActionCloseBtn = document.getElementById('itemActionCloseBtn');

const itemGiveSection = document.getElementById('itemGiveSection');
const itemGivePlayers = document.getElementById('itemGivePlayers');
const itemGiveRefreshBtn = document.getElementById('itemGiveRefreshBtn');
const itemGiveConfirmBtn = document.getElementById('itemGiveConfirmBtn');

const state = {
  inventory: { items: [], currentWeight: 0, maxWeight: 0 },
  nearbyPlayers: [],
  selectedItem: null
};

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });
  return response.json();
};

const closeInventory = async () => {
  await post('inventory:close');
};

const hideGiveSection = () => {
  itemGiveSection.classList.add('hidden');
  itemGivePlayers.innerHTML = '';
};

const renderNearbyPlayers = () => {
  const players = state.nearbyPlayers || [];
  itemGivePlayers.innerHTML = '';

  if (!players.length) {
    const option = document.createElement('option');
    option.value = '';
    option.textContent = 'Kein Spieler in 5m Nähe';
    itemGivePlayers.appendChild(option);
    itemGivePlayers.disabled = true;
    return;
  }

  itemGivePlayers.disabled = false;
  players.forEach((player) => {
    const option = document.createElement('option');
    option.value = String(player.id);
    option.textContent = `${player.name} (${player.id}) - ${player.distance}m`;
    itemGivePlayers.appendChild(option);
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

const getSelectedQuantity = () => {
  const maxQty = Math.max(1, Number(state.selectedItem?.quantity || 1));
  const value = Math.floor(Number(itemActionQty.value || 1));
  if (!Number.isFinite(value) || value <= 0) {
    return 1;
  }
  return Math.min(maxQty, value);
};

const closeItemModal = () => {
  state.selectedItem = null;
  hideGiveSection();
  itemActionModal.classList.add('hidden');
};

const openItemModal = (item) => {
  state.selectedItem = item;
  hideGiveSection();

  itemActionTitle.textContent = `${item.label} x${item.quantity}`;
  itemActionDescription.textContent = item.description || 'Inventar-Item';

  const maxQty = Math.max(1, Number(item.quantity || 1));
  itemActionQty.min = '1';
  itemActionQty.max = String(maxQty);
  itemActionQty.value = '1';

  itemActionButtons.innerHTML = '';

  const isWeaponItem = String(item.itemName || '').toLowerCase().startsWith('weapon_');
  if (item.usable && !isWeaponItem) {
    const useBtn = document.createElement('button');
    useBtn.type = 'button';
    useBtn.textContent = 'Benutzen';
    useBtn.addEventListener('click', async () => {
      await post('inventory:useItem', {
        itemName: item.itemName,
        quantity: getSelectedQuantity()
      });
      closeItemModal();
    });
    itemActionButtons.appendChild(useBtn);
  }

  const giveBtn = document.createElement('button');
  giveBtn.type = 'button';
  giveBtn.textContent = 'Geben';
  giveBtn.addEventListener('click', async () => {
    itemGiveSection.classList.remove('hidden');
    await refreshNearbyPlayers();
  });
  itemActionButtons.appendChild(giveBtn);

  const dropBtn = document.createElement('button');
  dropBtn.type = 'button';
  dropBtn.className = 'danger';
  dropBtn.textContent = 'Droppen';
  dropBtn.addEventListener('click', async () => {
    await post('inventory:dropItem', {
      itemName: item.itemName,
      quantity: getSelectedQuantity()
    });
    closeItemModal();
  });
  itemActionButtons.appendChild(dropBtn);

  itemActionModal.classList.remove('hidden');
};

const render = () => {
  const data = state.inventory || { items: [] };
  weightEl.textContent = `${Number(data.currentWeight || 0)} / ${Number(data.maxWeight || 0)} g`;
  itemsEl.innerHTML = '';

  if (!data.items?.length) {
    itemsEl.innerHTML = '<div class="item"><div class="titleWrap"><h3>Leer</h3><span class="count">x0</span></div></div>';
    return;
  }

  data.items.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'item';
    card.title = `${item.label} öffnen`;

    const head = document.createElement('div');
    head.className = 'itemHead';

    const icon = createIcon(item);
    const titleWrap = document.createElement('div');
    titleWrap.className = 'titleWrap';
    titleWrap.innerHTML = `
      <h3>${item.label}</h3>
      <span class="count">x${item.quantity}</span>
    `;

    head.appendChild(icon);
    head.appendChild(titleWrap);
    card.appendChild(head);

    card.addEventListener('click', () => {
      openItemModal(item);
    });

    itemsEl.appendChild(card);
  });
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    app.classList.remove('hidden');
    state.inventory = data || { items: [] };
    render();
  }
  if (action === 'update') {
    state.inventory = data || { items: [] };
    render();
  }
  if (action === 'close') {
    closeItemModal();
    app.classList.add('hidden');
  }
});

closeBtn.addEventListener('click', async () => {
  await closeInventory();
});

itemActionCloseBtn.addEventListener('click', () => {
  closeItemModal();
});

itemActionModal.addEventListener('click', (event) => {
  if (event.target === itemActionModal) {
    closeItemModal();
  }
});

itemGiveRefreshBtn.addEventListener('click', async () => {
  await refreshNearbyPlayers();
});

itemGiveConfirmBtn.addEventListener('click', async () => {
  if (!state.selectedItem) {
    return;
  }

  const targetId = Number(itemGivePlayers.value || 0);
  if (!targetId) {
    return;
  }

  await post('inventory:giveItem', {
    itemName: state.selectedItem.itemName,
    quantity: getSelectedQuantity(),
    targetId
  });

  closeItemModal();
});

window.addEventListener('keydown', async (event) => {
  if (event.key !== 'Escape') {
    return;
  }
  if (app.classList.contains('hidden')) {
    return;
  }

  event.preventDefault();
  if (!itemActionModal.classList.contains('hidden')) {
    closeItemModal();
    return;
  }

  await closeInventory();
});
