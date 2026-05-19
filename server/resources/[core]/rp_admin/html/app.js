const app = document.getElementById('app');
const tabsEl = document.getElementById('tabs');
const contentEl = document.getElementById('content');
const closeBtn = document.getElementById('closeBtn');
const viewerRoleEl = document.getElementById('viewerRole');
const footerInfoEl = document.getElementById('footerInfo');
const panelTitleEl = document.getElementById('panelTitle');

const state = {
  visible: false,
  mode: 'admin',
  activeTab: 'dashboard',
  data: null,
  ticketPreviewId: 0,
  rightsSelectedRole: '',
  banSearch: '',
  scriptSearch: '',
  shopSearch: '',
  settingsShopType: '',
  shopItemsModalShopId: 0,
  shopVehiclesModalShopId: 0,
  newRoleInsertAfter: ''
};

const tabConfig = [
  { key: 'dashboard', label: 'Dashboard', requires: 'dashboard.view' },
  { key: 'players', label: 'Spieler', requires: 'players.view' },
  { key: 'tickets', label: 'Tickets', requires: 'tickets.view' },
  { key: 'bans', label: 'Bans', requires: 'bans.view' },
  { key: 'rights', label: 'Rechte', requires: 'rights.view' },
  { key: 'scripts', label: 'Scripts', requires: 'scripts.view' },
  { key: 'settings', label: 'Einstellungen', requires: 'settings.view' }
];

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function hasPerm(key) {
  return !!state.data?.viewer?.permissions?.[key];
}

function parseNullableNumber(raw) {
  const text = String(raw ?? '').trim();
  if (text === '') return null;
  const value = Number(text);
  if (Number.isNaN(value)) return null;
  return value;
}

function formatCoord(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return '-';
  }
  return numeric.toFixed(2);
}

function getShopTypeLabel(type) {
  if (type === '24_7') return '24/7 Shop';
  if (type === 'vehicle') return 'Autohaus';
  if (type === 'clothing') return 'Kleidungsshop';
  if (type === 'garage') return 'Garagen';
  return String(type || '-');
}

function getSelectedRightsRole() {
  const roles = state.data?.roles || [];
  if (!roles.length) {
    return '';
  }

  const exists = roles.find((r) => r.role_name === state.rightsSelectedRole);
  if (exists) {
    return state.rightsSelectedRole;
  }

  state.rightsSelectedRole = roles[0].role_name;
  return state.rightsSelectedRole;
}

function post(action, data = {}) {
  return fetch(`https://${GetParentResourceName()}/admin:action`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({ action, data })
  });
}

function setFooter(text) {
  footerInfoEl.textContent = text || 'Bereit';
}

function setVisible(visible) {
  state.visible = visible;
  app.classList.toggle('hidden', !visible);
  if (!visible) {
    closeTicketPreview();
    closeConfirmModal();
    closePlayerActionModal();
    closePlayerManageModal();
    closeShopItemsModal();
    closeShopVehiclesModal();
  }
}

function rowHeader(cols, className = '') {
  const extraClass = className ? ` ${className}` : '';
  return `<div class="row header${extraClass}">${cols.map((c) => `<div>${escapeHtml(c)}</div>`).join('')}</div>`;
}

function renderEmptyRow(message, className = '') {
  const extraClass = className ? ` ${className}` : '';
  return `<div class="row empty${extraClass}"><div class="empty-cell muted">${escapeHtml(message)}</div></div>`;
}

function renderTicketStatus(status) {
  if (status === 'in_progress') return 'In Bearbeitung';
  if (status === 'closed') return 'Geschlossen';
  return 'Offen';
}

function formatDateTime(value) {
  if (value === null || value === undefined || value === '') {
    return '-';
  }

  if (typeof value === 'number' || (/^\d+$/).test(String(value))) {
    let ts = Number(value);
    if (ts > 100000000000) {
      // Milliseconds timestamp
    } else if (ts > 1000000000) {
      // Seconds timestamp
      ts = ts * 1000;
    } else {
      return String(value);
    }

    const d = new Date(ts);
    if (!Number.isNaN(d.getTime())) {
      return d.toLocaleString('de-DE');
    }
  }

  const parsed = new Date(String(value));
  if (!Number.isNaN(parsed.getTime())) {
    return parsed.toLocaleString('de-DE');
  }

  return String(value);
}

function formatDateParts(value) {
  const text = formatDateTime(value);
  if (text === '-' || text === '') {
    return { date: '-', time: '-' };
  }

  const parts = text.split(',').map((v) => v.trim());
  if (parts.length >= 2) {
    return { date: parts[0], time: parts[1] };
  }

  return { date: text, time: '-' };
}

function findTicketById(ticketId) {
  const tickets = state.data?.tickets || [];
  return tickets.find((t) => Number(t.id) === Number(ticketId)) || null;
}

function closeTicketPreview() {
  const modal = document.getElementById('ticketPreviewModal');
  if (modal) {
    modal.remove();
  }
  state.ticketPreviewId = 0;
}

function closeConfirmModal() {
  const modal = document.getElementById('confirmModal');
  if (modal) {
    modal.remove();
  }
}

function openConfirmModal({ title, text, confirmLabel = 'Bestätigen', onConfirm }) {
  closeConfirmModal();

  const modal = document.createElement('div');
  modal.id = 'confirmModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>${escapeHtml(title || 'Bestätigung')}</h3>
        <button type="button" class="btn ghost" data-action="confirmModalClose">Schließen</button>
      </div>
      <div class="modal-body">
        <p>${escapeHtml(text || '')}</p>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" data-action="confirmModalClose">Abbrechen</button>
        <button type="button" class="btn danger" data-action="confirmModalAccept">${escapeHtml(confirmLabel)}</button>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  modal.addEventListener('click', (event) => {
    if (event.target === modal) {
      closeConfirmModal();
    }
  });

  modal.querySelectorAll('[data-action="confirmModalClose"]').forEach((el) => {
    el.addEventListener('click', () => closeConfirmModal());
  });

  const acceptBtn = modal.querySelector('[data-action="confirmModalAccept"]');
  if (acceptBtn) {
    acceptBtn.addEventListener('click', async () => {
      acceptBtn.disabled = true;
      try {
        if (typeof onConfirm === 'function') {
          await onConfirm();
        }
      } finally {
        closeConfirmModal();
      }
    });
  }
}

function openTicketPreview(ticketId) {
  const ticket = findTicketById(ticketId);
  if (!ticket) {
    setFooter('Ticket nicht gefunden.');
    return;
  }

  closeTicketPreview();
  state.ticketPreviewId = Number(ticketId);

  const modal = document.createElement('div');
  modal.id = 'ticketPreviewModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card">
      <div class="modal-head">
        <h3>Ticket #${escapeHtml(ticket.id)}</h3>
        <button type="button" class="btn ghost" data-action="modalClose">Schließen</button>
      </div>
      <div class="modal-meta">
        <span>Spieler: ${escapeHtml(ticket.creator_name || '-')}</span>
        <span>Status: ${escapeHtml(renderTicketStatus(ticket.status))}</span>
      </div>
      <div class="modal-body">
        <div class="ticket-preview-title">${escapeHtml(ticket.title || '')}</div>
        <pre class="ticket-preview-text">${escapeHtml(ticket.description || '')}</pre>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn primary" data-action="modalClaim">Beanspruchen</button>
        <button type="button" class="btn ghost" data-action="modalClose">Zurück</button>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  modal.querySelectorAll('[data-action="modalClose"]').forEach((el) => {
    el.addEventListener('click', () => closeTicketPreview());
  });

  const claimBtn = modal.querySelector('[data-action="modalClaim"]');
  if (claimBtn) {
    claimBtn.addEventListener('click', async () => {
      await post('tickets.claim', { ticketId: Number(ticket.id) });
      setFooter(`Ticket #${ticket.id} wird beansprucht ...`);
      closeTicketPreview();
    });
  }
}

function closePlayerActionModal() {
  const modal = document.getElementById('playerActionModal');
  if (modal) {
    modal.remove();
  }
}

function closePlayerManageModal() {
  const modal = document.getElementById('playerManageModal');
  if (modal) {
    modal.remove();
  }
}

function closeShopItemsModal() {
  const modal = document.getElementById('shopItemsModal');
  if (modal) {
    modal.remove();
  }
  state.shopItemsModalShopId = 0;
}

function openShopItemsModal(shopId) {
  const settings = state.data?.settings || {};
  const shops = settings.shops || [];
  const inventoryItems = settings.inventoryItems || [];
  const shopItems = settings.shopItems || [];
  const shop = shops.find((entry) => Number(entry.id) === Number(shopId));

  if (!shop) {
    setFooter('Shop wurde nicht gefunden.');
    return;
  }

  closeShopItemsModal();
  state.shopItemsModalShopId = Number(shopId);

  const currentItems = shopItems.filter((entry) => Number(entry.shop_id) === Number(shopId));
  const modal = document.createElement('div');
  modal.id = 'shopItemsModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>Shop-Items: ${escapeHtml(shop.label || shop.shop_code || `Shop ${shopId}`)}</h3>
        <button type="button" class="btn ghost" data-action="closeShopItemsModal">Schließen</button>
      </div>
      <div class="modal-body">
        <div class="list" style="margin-bottom:12px;">
          ${rowHeader(['Item', 'Label', 'Preis', 'Währung', 'Aktiv'], 'row-shop-items')}
          ${currentItems.map((entry) => `
            <div class="row row-shop-items">
              <div>${escapeHtml(entry.item_id)}</div>
              <div>${escapeHtml(entry.label || '-')}</div>
              <div>${escapeHtml(entry.price)}</div>
              <div>${escapeHtml((entry.currency || 'cash').toUpperCase())}</div>
              <div class="actions">
                <button class="btn ghost" type="button" data-action="removeShopItem" data-shopid="${escapeHtml(shopId)}" data-itemid="${escapeHtml(entry.item_id)}">Entfernen</button>
              </div>
            </div>
          `).join('') || renderEmptyRow('Noch keine Items in diesem Shop.', 'row-shop-items')}
        </div>

        <div class="form-grid full">
          <label class="muted">Item hinzufügen / aktualisieren</label>
          <select id="shopItemSelect">
            ${inventoryItems.map((item) => `<option value="${escapeHtml(item.id)}">${escapeHtml(item.label)} (${escapeHtml(item.item_name)})</option>`).join('')}
          </select>
          <div class="actions">
            <input id="shopItemPrice" type="number" min="0" step="1" value="15" placeholder="Preis" />
            <select id="shopItemCurrency">
              <option value="cash">Bargeld</option>
              <option value="bank">Bank</option>
            </select>
            <button class="btn primary" id="shopItemSaveBtn" type="button">Speichern</button>
          </div>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  modal.querySelectorAll('[data-action="closeShopItemsModal"]').forEach((el) => {
    el.addEventListener('click', () => closeShopItemsModal());
  });

  modal.querySelectorAll('[data-action="removeShopItem"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const removeShopId = Number(el.dataset.shopid || 0);
      const removeItemId = Number(el.dataset.itemid || 0);
      if (!removeShopId || !removeItemId) return;
      await post('settings.shops.removeItem', { shopId: removeShopId, itemId: removeItemId });
      setFooter('Shop-Item wird entfernt ...');
      closeShopItemsModal();
    });
  });

  const saveBtn = modal.querySelector('#shopItemSaveBtn');
  if (saveBtn) {
    saveBtn.addEventListener('click', async () => {
      const itemId = Number(modal.querySelector('#shopItemSelect')?.value || 0);
      const price = Number(modal.querySelector('#shopItemPrice')?.value || 0);
      const currency = String(modal.querySelector('#shopItemCurrency')?.value || 'cash');
      await post('settings.shops.addItem', { shopId: Number(shopId), itemId, price, currency });
      setFooter(`Shop-Item für Shop ${shopId} wird gespeichert ...`);
      closeShopItemsModal();
    });
  }
}

function closeShopVehiclesModal() {
  const modal = document.getElementById('shopVehiclesModal');
  if (modal) {
    modal.remove();
  }
  state.shopVehiclesModalShopId = 0;
}

function openShopVehiclesModal(shopId) {
  const settings = state.data?.settings || {};
  const shops = settings.shops || [];
  const vehicleCatalog = settings.vehicleCatalog || [];
  const shopVehicles = settings.shopVehicles || [];
  const shop = shops.find((entry) => Number(entry.id) === Number(shopId));

  if (!shop) {
    setFooter('Shop wurde nicht gefunden.');
    return;
  }

  closeShopVehiclesModal();
  state.shopVehiclesModalShopId = Number(shopId);

  const currentVehicles = shopVehicles.filter((entry) => Number(entry.shop_id) === Number(shopId));
  const modal = document.createElement('div');
  modal.id = 'shopVehiclesModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>Autohaus-Angebote: ${escapeHtml(shop.label || shop.shop_code || `Shop ${shopId}`)}</h3>
        <button type="button" class="btn ghost" data-action="closeShopVehiclesModal">Schließen</button>
      </div>
      <div class="modal-body">
        <div class="list" style="margin-bottom:12px;">
          ${rowHeader(['Fahrzeug', 'Modell', 'Preis', 'Aktion'], 'row-shop-items')}
          ${currentVehicles.map((entry) => `
            <div class="row row-shop-items">
              <div>${escapeHtml(entry.label || '-')}</div>
              <div>${escapeHtml(entry.model || '-')}</div>
              <div>${escapeHtml(entry.price)}</div>
              <div class="actions">
                <button class="btn ghost" type="button" data-action="removeShopVehicle" data-shopid="${escapeHtml(shopId)}" data-vehicleid="${escapeHtml(entry.vehicle_id)}">Entfernen</button>
              </div>
            </div>
          `).join('') || renderEmptyRow('Noch keine Fahrzeuge in diesem Autohaus.', 'row-shop-items')}
        </div>

        <div class="form-grid full">
          <label class="muted">Fahrzeug hinzufügen / aktualisieren</label>
          <select id="shopVehicleSelect">
            ${vehicleCatalog.filter((v) => Number(v.enabled) === 1).map((vehicle) => `
              <option value="${escapeHtml(vehicle.id)}" data-price="${escapeHtml(vehicle.price)}">
                ${escapeHtml(vehicle.label)} (${escapeHtml(vehicle.model)}) - Standard ${escapeHtml(vehicle.price)}$
              </option>
            `).join('')}
          </select>
          <div class="actions">
            <input id="shopVehiclePrice" type="number" min="0" step="1" value="10000" placeholder="Preis" />
            <button class="btn primary" id="shopVehicleSaveBtn" type="button">Speichern</button>
          </div>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  modal.querySelectorAll('[data-action="closeShopVehiclesModal"]').forEach((el) => {
    el.addEventListener('click', () => closeShopVehiclesModal());
  });

  modal.querySelectorAll('[data-action="removeShopVehicle"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const removeShopId = Number(el.dataset.shopid || 0);
      const removeVehicleId = Number(el.dataset.vehicleid || 0);
      if (!removeShopId || !removeVehicleId) return;
      await post('settings.shops.removeVehicle', { shopId: removeShopId, vehicleId: removeVehicleId });
      setFooter('Autohaus-Fahrzeug wird entfernt ...');
      closeShopVehiclesModal();
    });
  });

  const vehicleSelect = modal.querySelector('#shopVehicleSelect');
  const vehiclePrice = modal.querySelector('#shopVehiclePrice');
  if (vehicleSelect && vehiclePrice) {
    const syncVehiclePrice = () => {
      const selectedOption = vehicleSelect.options[vehicleSelect.selectedIndex];
      const defaultPrice = Number(selectedOption?.dataset?.price || 0);
      if (defaultPrice >= 0) {
        vehiclePrice.value = String(defaultPrice);
      }
    };
    vehicleSelect.addEventListener('change', syncVehiclePrice);
    syncVehiclePrice();
  }

  const saveBtn = modal.querySelector('#shopVehicleSaveBtn');
  if (saveBtn) {
    saveBtn.addEventListener('click', async () => {
      const vehicleId = Number(modal.querySelector('#shopVehicleSelect')?.value || 0);
      const price = Number(modal.querySelector('#shopVehiclePrice')?.value || 0);
      await post('settings.shops.addVehicle', { shopId: Number(shopId), vehicleId, price });
      setFooter(`Autohaus-Fahrzeug für Shop ${shopId} wird gespeichert ...`);
      closeShopVehiclesModal();
    });
  }
}

function closeShopEditModal() {
  const modal = document.getElementById('shopEditModal');
  if (modal) {
    modal.remove();
  }
}

function openShopEditModal(shopId) {
  const settings = state.data?.settings || {};
  const shops = settings.shops || [];
  const shop = shops.find((entry) => Number(entry.id) === Number(shopId));
  if (!shop) {
    setFooter('Shop wurde nicht gefunden.');
    return;
  }

  closeShopEditModal();
  const isClothing = String(shop.shop_type) === 'clothing';
  const isVehicle = String(shop.shop_type) === 'vehicle';
  const is247 = String(shop.shop_type) === '24_7';

  const modal = document.createElement('div');
  modal.id = 'shopEditModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>${escapeHtml(getShopTypeLabel(shop.shop_type))} bearbeiten (#${escapeHtml(shop.id)})</h3>
        <button type="button" class="btn ghost" data-action="closeShopEditModal">Schließen</button>
      </div>
      <div class="modal-body">
        <div class="form-grid full">
          ${isClothing ? '' : `<input id="editShopLabel" type="text" placeholder="Name" value="${escapeHtml(shop.label || '')}" />`}
          ${isClothing ? '' : `
          <div class="actions">
            <label class="inline-check"><input id="editShopBlipEnabled" type="checkbox" ${Number(shop.blip_enabled) === 1 ? 'checked' : ''} /> Blip anzeigen</label>
            <label class="inline-check"><input id="editShopEnabled" type="checkbox" ${Number(shop.enabled) === 1 ? 'checked' : ''} /> Aktiv</label>
          </div>`}
          ${isClothing ? `<label class="muted">Kleidungsshop: Hier können nur die Positionspunkte geändert werden.</label>` : ''}
          <input id="editShopX" type="number" step="0.01" placeholder="X" value="${escapeHtml(shop.pos_x ?? '')}" />
          <input id="editShopY" type="number" step="0.01" placeholder="Y" value="${escapeHtml(shop.pos_y ?? '')}" />
          <input id="editShopZ" type="number" step="0.01" placeholder="Z" value="${escapeHtml(shop.pos_z ?? '')}" />
          <input id="editShopH" type="number" step="0.01" placeholder="Heading" value="${escapeHtml(shop.heading ?? '')}" />
        </div>

        <div class="actions" style="margin-top:10px;">
          <button class="btn ghost" id="editShopUseCurrentCoordsBtn" type="button">Aktuelle Position übernehmen</button>
          <button class="btn primary" id="editShopSaveBtn" type="button">Speichern</button>
          ${is247 ? `<button class="btn ghost" id="editShopItemsBtn" type="button">Items bearbeiten</button>` : ''}
          ${isVehicle ? `<button class="btn ghost" id="editShopVehiclesBtn" type="button">Fahrzeuge bearbeiten</button>` : ''}
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  modal.querySelectorAll('[data-action="closeShopEditModal"]').forEach((el) => {
    el.addEventListener('click', () => closeShopEditModal());
  });

  const useCurrentCoordsBtn = modal.querySelector('#editShopUseCurrentCoordsBtn');
  if (useCurrentCoordsBtn) {
    useCurrentCoordsBtn.addEventListener('click', async () => {
      await post('settings.shops.useCurrentCoords', {});
      setFooter('Aktuelle Position wird übernommen ...');
      closeShopEditModal();
    });
  }

  const saveBtn = modal.querySelector('#editShopSaveBtn');
  if (saveBtn) {
    saveBtn.addEventListener('click', async () => {
      const payload = {
        shopId: Number(shop.id),
        label: modal.querySelector('#editShopLabel')?.value || shop.label || '',
        blipEnabled: (modal.querySelector('#editShopBlipEnabled')?.checked ?? (Number(shop.blip_enabled) === 1)) === true,
        enabled: (modal.querySelector('#editShopEnabled')?.checked ?? (Number(shop.enabled) === 1)) === true,
        coords: {
          x: parseNullableNumber(modal.querySelector('#editShopX')?.value),
          y: parseNullableNumber(modal.querySelector('#editShopY')?.value),
          z: parseNullableNumber(modal.querySelector('#editShopZ')?.value),
          h: parseNullableNumber(modal.querySelector('#editShopH')?.value)
        }
      };
      await post('settings.shops.update', payload);
      setFooter(`Shop #${shop.id} wird gespeichert ...`);
      closeShopEditModal();
    });
  }

  const itemsBtn = modal.querySelector('#editShopItemsBtn');
  if (itemsBtn) {
    itemsBtn.addEventListener('click', () => {
      closeShopEditModal();
      openShopItemsModal(Number(shop.id));
    });
  }

  const vehiclesBtn = modal.querySelector('#editShopVehiclesBtn');
  if (vehiclesBtn) {
    vehiclesBtn.addEventListener('click', () => {
      closeShopEditModal();
      openShopVehiclesModal(Number(shop.id));
    });
  }
}

function closeGarageEditModal() {
  const modal = document.getElementById('garageEditModal');
  if (modal) {
    modal.remove();
  }
}

function openGarageEditModal(garageId) {
  const settings = state.data?.settings || {};
  const garages = settings.garages || [];
  const garage = garages.find((entry) => Number(entry.id) === Number(garageId));
  if (!garage) {
    setFooter('Garage wurde nicht gefunden.');
    return;
  }

  closeGarageEditModal();

  const modal = document.createElement('div');
  modal.id = 'garageEditModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>Garage bearbeiten (#${escapeHtml(garage.id)})</h3>
        <button type="button" class="btn ghost" data-action="closeGarageEditModal">Schließen</button>
      </div>
      <div class="modal-body">
        <div class="form-grid full">
          <input id="editGarageLabel" type="text" placeholder="Name" value="${escapeHtml(garage.label || '')}" />
          <div class="actions">
            <label class="inline-check"><input id="editGarageBlipEnabled" type="checkbox" ${Number(garage.blip_enabled) === 1 ? 'checked' : ''} /> Blip anzeigen</label>
            <label class="inline-check"><input id="editGarageEnabled" type="checkbox" ${Number(garage.enabled) === 1 ? 'checked' : ''} /> Aktiv</label>
          </div>
          <label class="muted">Marker (Einparken/Ausparken)</label>
          <input id="editGarageX" type="number" step="0.01" placeholder="Marker X" value="${escapeHtml(garage.pos_x ?? '')}" />
          <input id="editGarageY" type="number" step="0.01" placeholder="Marker Y" value="${escapeHtml(garage.pos_y ?? '')}" />
          <input id="editGarageZ" type="number" step="0.01" placeholder="Marker Z" value="${escapeHtml(garage.pos_z ?? '')}" />
          <label class="muted">Spawn</label>
          <input id="editGarageSpawnX" type="number" step="0.01" placeholder="Spawn X" value="${escapeHtml(garage.spawn_x ?? '')}" />
          <input id="editGarageSpawnY" type="number" step="0.01" placeholder="Spawn Y" value="${escapeHtml(garage.spawn_y ?? '')}" />
          <input id="editGarageSpawnZ" type="number" step="0.01" placeholder="Spawn Z" value="${escapeHtml(garage.spawn_z ?? '')}" />
          <input id="editGarageSpawnH" type="number" step="0.01" placeholder="Spawn Heading" value="${escapeHtml(garage.spawn_heading ?? '')}" />
        </div>

        <div class="actions" style="margin-top:10px;">
          <button class="btn ghost" id="editGarageUseCurrentMarkerBtn" type="button">Marker von aktueller Position</button>
          <button class="btn ghost" id="editGarageUseCurrentSpawnBtn" type="button">Spawn von aktueller Position</button>
          <button class="btn primary" id="editGarageSaveBtn" type="button">Speichern</button>
          <button class="btn danger" id="editGarageDeleteBtn" type="button">Löschen</button>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  modal.querySelectorAll('[data-action="closeGarageEditModal"]').forEach((el) => {
    el.addEventListener('click', () => closeGarageEditModal());
  });

  const useMarkerBtn = modal.querySelector('#editGarageUseCurrentMarkerBtn');
  if (useMarkerBtn) {
    useMarkerBtn.addEventListener('click', async () => {
      await post('settings.garages.useCurrentMarkerCoords', {});
      setFooter('Aktuelle Position wird als Marker übernommen ...');
      closeGarageEditModal();
    });
  }

  const useSpawnBtn = modal.querySelector('#editGarageUseCurrentSpawnBtn');
  if (useSpawnBtn) {
    useSpawnBtn.addEventListener('click', async () => {
      await post('settings.garages.useCurrentSpawnCoords', {});
      setFooter('Aktuelle Position wird als Spawn übernommen ...');
      closeGarageEditModal();
    });
  }

  const saveBtn = modal.querySelector('#editGarageSaveBtn');
  if (saveBtn) {
    saveBtn.addEventListener('click', async () => {
      const payload = {
        garageId: Number(garage.id),
        label: modal.querySelector('#editGarageLabel')?.value || garage.label || '',
        blipEnabled: (modal.querySelector('#editGarageBlipEnabled')?.checked ?? (Number(garage.blip_enabled) === 1)) === true,
        enabled: (modal.querySelector('#editGarageEnabled')?.checked ?? (Number(garage.enabled) === 1)) === true,
        markerCoords: {
          x: parseNullableNumber(modal.querySelector('#editGarageX')?.value),
          y: parseNullableNumber(modal.querySelector('#editGarageY')?.value),
          z: parseNullableNumber(modal.querySelector('#editGarageZ')?.value)
        },
        spawnCoords: {
          x: parseNullableNumber(modal.querySelector('#editGarageSpawnX')?.value),
          y: parseNullableNumber(modal.querySelector('#editGarageSpawnY')?.value),
          z: parseNullableNumber(modal.querySelector('#editGarageSpawnZ')?.value),
          h: parseNullableNumber(modal.querySelector('#editGarageSpawnH')?.value)
        }
      };
      await post('settings.garages.update', payload);
      setFooter(`Garage #${garage.id} wird gespeichert ...`);
      closeGarageEditModal();
    });
  }

  const deleteBtn = modal.querySelector('#editGarageDeleteBtn');
  if (deleteBtn) {
    deleteBtn.addEventListener('click', async () => {
      await post('settings.garages.remove', { garageId: Number(garage.id) });
      setFooter(`Garage #${garage.id} wird gelöscht ...`);
      closeGarageEditModal();
    });
  }
}

function openPlayerManageModal(player) {
  if (!player) return;
  closePlayerManageModal();

  const canAssignRole = hasPerm('rights.assign');
  const roles = state.data?.roles || [];
  const currentRoleName = (player.roleName && player.roleName !== 'none') ? player.roleName : 'spieler';
  const currentRoleLabel = (player.roleLabel && player.roleLabel !== 'Kein Rang') ? player.roleLabel : 'Spieler';
  const roleOptions = ['<option value="spieler">Spieler (kein Teamrang)</option>']
    .concat(roles.map((r) => `<option value="${escapeHtml(r.role_name)}">${escapeHtml(r.label)}</option>`))
    .join('');

  const modal = document.createElement('div');
  modal.id = 'playerManageModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>Spieler verwalten</h3>
        <button type="button" class="btn ghost" data-action="closePlayerManageModal">Schließen</button>
      </div>
      <div class="modal-body">
        <div class="modal-meta">
          <span>Profil: ${escapeHtml(player.name || '-')}</span>
          <span>Charakter: ${escapeHtml(player.characterName || '-')}</span>
          <span>Status: ${player.online ? 'Live' : 'Offline'}</span>
          <span>ID: ${player.online ? escapeHtml(player.source) : '-'}</span>
          <span>User-ID: ${escapeHtml(player.userId || '-')}</span>
          <span>Aktueller Rang: ${escapeHtml(currentRoleLabel)}</span>
        </div>

        ${canAssignRole ? `
        <div class="form-grid full" style="margin-top:10px;">
          <label class="muted">Neuen Rang setzen / Rang entfernen</label>
          <div class="actions">
            <select id="playerManageRoleSelect">
              ${roleOptions}
            </select>
            <button type="button" class="btn primary" id="playerManageSaveRoleBtn">Rang speichern</button>
          </div>
        </div>
        ` : `
        <p class="muted" style="margin-top:10px;">Für Rangänderungen brauchst du Projektleitung-Rechte.</p>
        `}

        <div class="actions" style="margin-top:14px;">
          ${hasPerm('players.kick') && player.online ? `<button type="button" class="btn ghost" data-action="playerManageKick">Kick</button>` : ''}
          ${hasPerm('players.ban') ? `<button type="button" class="btn danger" data-action="playerManageBan">Ban</button>` : ''}
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  modal.querySelectorAll('[data-action="closePlayerManageModal"]').forEach((el) => {
    el.addEventListener('click', () => closePlayerManageModal());
  });

  const roleSelect = modal.querySelector('#playerManageRoleSelect');
  if (roleSelect) {
    roleSelect.value = currentRoleName;
  }

  const saveRoleBtn = modal.querySelector('#playerManageSaveRoleBtn');
  if (saveRoleBtn) {
    saveRoleBtn.addEventListener('click', async () => {
      if (!player.userId) {
        setFooter('Dieser Spieler hat keine gültige User-ID.');
        return;
      }
      const roleName = (modal.querySelector('#playerManageRoleSelect')?.value || 'spieler').trim();
      await post('rights.assignRole', { targetUserId: Number(player.userId), roleName });
      setFooter(`Rang für User ${player.userId} wird gespeichert ...`);
      closePlayerManageModal();
    });
  }

  const kickBtn = modal.querySelector('[data-action="playerManageKick"]');
  if (kickBtn) {
    kickBtn.addEventListener('click', () => {
      closePlayerManageModal();
      openPlayerActionModal('kick', {
        targetSource: Number(player.source || 0),
        targetUserId: Number(player.userId || 0),
        targetName: player.characterName || player.name || 'Spieler',
        isOnline: !!player.online
      });
    });
  }

  const banBtn = modal.querySelector('[data-action="playerManageBan"]');
  if (banBtn) {
    banBtn.addEventListener('click', () => {
      closePlayerManageModal();
      openPlayerActionModal('ban', {
        targetSource: Number(player.source || 0),
        targetUserId: Number(player.userId || 0),
        targetName: player.characterName || player.name || 'Spieler',
        isOnline: !!player.online
      });
    });
  }
}

function openPlayerActionModal(kind, target) {
  closePlayerActionModal();

  const isBan = kind === 'ban';
  const targetSource = Number(target?.targetSource || 0);
  const targetUserId = Number(target?.targetUserId || 0);
  const targetName = target?.targetName || 'Spieler';
  const isOnline = !!target?.isOnline;
  const modal = document.createElement('div');
  modal.id = 'playerActionModal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal-card modal-small">
      <div class="modal-head">
        <h3>${isBan ? 'Spieler bannen' : 'Spieler kicken'}</h3>
        <button type="button" class="btn ghost" data-action="closeActionModal">Schließen</button>
      </div>
      <div class="modal-body">
        <div class="modal-meta">
          <span>Ziel: ${escapeHtml(targetName || 'Spieler')}</span>
          <span>Server-ID: ${isOnline ? escapeHtml(targetSource) : 'Offline'}</span>
          <span>User-ID: ${targetUserId > 0 ? escapeHtml(targetUserId) : '-'}</span>
        </div>
        <div class="form-grid full" style="margin-top:10px;">
          <label class="muted">Grund</label>
          <textarea id="actionReasonInput" placeholder="${isBan ? 'Ban-Grund eingeben...' : 'Kick-Grund eingeben...'}"></textarea>
          ${isBan ? `
            <label class="muted">Dauer in Stunden (0 = permanent)</label>
            <input id="actionDurationInput" type="number" min="0" value="24" />
          ` : ''}
        </div>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn primary" data-action="confirmActionModal">${isBan ? 'Ban ausführen' : 'Kick ausführen'}</button>
        <button type="button" class="btn ghost" data-action="closeActionModal">Abbrechen</button>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  modal.querySelectorAll('[data-action="closeActionModal"]').forEach((el) => {
    el.addEventListener('click', () => closePlayerActionModal());
  });

  const confirmBtn = modal.querySelector('[data-action="confirmActionModal"]');
  if (confirmBtn) {
    confirmBtn.addEventListener('click', async () => {
      const reason = (document.getElementById('actionReasonInput')?.value || '').trim();
      if (!reason) {
        setFooter(`${isBan ? 'Ban' : 'Kick'} abgebrochen: Kein Grund angegeben.`);
        return;
      }

      if (!isBan && !isOnline) {
        setFooter('Kick nur bei Live-Spielern möglich.');
        return;
      }

      if (isBan) {
        const durationHours = Number(document.getElementById('actionDurationInput')?.value || 24);
        await post('players.ban', { targetSource, targetUserId, reason, durationHours });
      } else {
        await post('players.kick', { targetSource, reason });
      }

      closePlayerActionModal();
    });
  }
}

function getAvailableTabs() {
  return tabConfig.filter((t) => {
    if (!hasPerm(t.requires)) return false;
    return true;
  });
}

function renderTabs() {
  if (state.mode !== 'admin') {
    tabsEl.innerHTML = '';
    return;
  }

  const available = getAvailableTabs();
  if (!available.find((t) => t.key === state.activeTab)) {
    state.activeTab = available[0]?.key || 'dashboard';
  }

  tabsEl.innerHTML = available.map((tab) => `
    <button class="tab-btn ${tab.key === state.activeTab ? 'active' : ''}" data-tab="${tab.key}">
      ${escapeHtml(tab.label)}
    </button>
  `).join('');

  [...tabsEl.querySelectorAll('.tab-btn')].forEach((btn) => {
    btn.addEventListener('click', () => {
      state.activeTab = btn.dataset.tab;
      render();
    });
  });
}

function renderDashboard() {
  const stats = state.data?.stats || {};
  const players = state.data?.dashboardPlayers || (state.data?.players || []).filter((p) => p?.online === true);

  return `
    <section class="grid">
      <div class="kpis">
        <div class="kpi"><div class="label">Spieler online</div><div class="value">${Number(stats.onlineCount || 0)}</div></div>
        <div class="kpi"><div class="label">Aktive Bans</div><div class="value">${stats.activeBans || 0}</div></div>
        <div class="kpi"><div class="label">Offene Tickets</div><div class="value">${stats.openTickets || 0}</div></div>
      </div>
      <div class="card">
        <h3>Online-Spieler</h3>
        <div class="list">
          ${rowHeader(['ID', 'Charakter', 'Profilname', 'User-ID', 'Rang', 'Ping'], 'row-dashboard')}
          ${players.map((p) => `
            <div class="row row-dashboard">
              <div>${p.source}</div>
              <div>${escapeHtml(p.characterName || '-')}</div>
              <div>${escapeHtml(p.name || '-')}</div>
              <div>${escapeHtml(p.userId || '-')}</div>
              <div>${escapeHtml(p.roleLabel || 'Kein Rang')}</div>
              <div>${escapeHtml(p.ping)}</div>
            </div>
          `).join('') || renderEmptyRow('Keine Spieler online.', 'row-dashboard')}
        </div>
      </div>
    </section>
  `;
}

function renderPlayers() {
  const players = state.data?.players || [];
  const canKick = hasPerm('players.kick');
  const canBan = hasPerm('players.ban');
  const mode = state.data?.playerListMode === 'offline' ? 'offline' : 'live';
  const isOfflineMode = mode === 'offline';

  return `
    <section class="grid">
      <div class="card">
        <h3>Spieler suchen und verwalten</h3>
        <div class="actions" style="margin-bottom:10px;">
          <input id="playerSearch" type="text" placeholder="Name / ID / User-ID" value="${escapeHtml(state.data?.search || '')}" />
          <button class="btn primary" id="searchBtn" type="button">Suchen</button>
          <select id="playerModeSelect">
            <option value="live" ${mode === 'live' ? 'selected' : ''}>Live</option>
            <option value="offline" ${mode === 'offline' ? 'selected' : ''}>Offline</option>
          </select>
          <button class="btn ghost" id="refreshBtn" type="button">Aktualisieren</button>
        </div>
        <div class="list">
          ${rowHeader(['ID', 'Charakter', 'Profilname', 'User-ID', 'Rang', 'Status', 'Ping', 'Aktionen'], 'row-players')}
          ${players.map((p) => `
            <div class="row row-players player-row" data-action="openPlayerModal"
                 data-source="${escapeHtml(p.source)}"
                 data-userid="${escapeHtml(p.userId || '')}"
                 data-name="${escapeHtml(p.name || '')}"
                 data-character="${escapeHtml(p.characterName || '')}"
                 data-role-name="${escapeHtml(p.roleName || 'none')}"
                 data-role-label="${escapeHtml(p.roleLabel || 'Kein Rang')}"
                 data-online="${p.online ? '1' : '0'}">
              <div>${p.online ? p.source : '-'}</div>
              <div>${escapeHtml(p.characterName || '-')}</div>
              <div>${escapeHtml(p.name || '-')}</div>
              <div>${escapeHtml(p.userId || '-')}</div>
              <div>${escapeHtml(p.roleLabel || 'Kein Rang')}</div>
              <div>${p.online ? 'Live' : 'Offline'}</div>
              <div>${escapeHtml(p.ping)}</div>
              <div class="actions">
                ${canKick && p.online ? `<button class="btn ghost" data-action="kick" data-source="${p.source}" data-userid="${p.userId || ''}" data-name="${escapeHtml(p.characterName || p.name || 'Spieler')}" data-online="1">Kick</button>` : ''}
                ${canBan ? `<button class="btn danger" data-action="ban" data-source="${p.source}" data-userid="${p.userId || ''}" data-name="${escapeHtml(p.characterName || p.name || 'Spieler')}" data-online="${p.online ? '1' : '0'}">Ban</button>` : ''}
              </div>
            </div>
          `).join('') || renderEmptyRow(isOfflineMode ? 'Keine Offline-Spieler gefunden.' : 'Keine Live-Spieler gefunden.', 'row-players')}
        </div>
      </div>
    </section>
  `;
}

function renderBans() {
  const bansRaw = state.data?.bans || [];
  const canManageBans = hasPerm('bans.manage');
  const searchText = String(state.banSearch || '').trim().toLowerCase();
  const bans = searchText
    ? bansRaw.filter((b) => {
      const haystack = [
        b.id,
        b.user_id,
        b.banned_by_user_id,
        b.banned_profile_name,
        b.banned_by_profile_name,
        b.reason
      ].map((v) => String(v ?? '').toLowerCase()).join(' ');

      return haystack.includes(searchText);
    })
    : bansRaw;

  return `
    <section class="card">
      <h3>Bans</h3>
      <div class="actions" style="margin-bottom:10px;">
        <input id="banSearch" type="text" placeholder="Ban-ID / User-ID / Profilname / Grund" value="${escapeHtml(state.banSearch || '')}" />
        <button class="btn primary" id="banSearchBtn" type="button">Suchen</button>
        <button class="btn ghost" id="banSearchResetBtn" type="button">Zurücksetzen</button>
      </div>
      <div class="list">
        ${rowHeader(['Ban-ID', 'User-ID', 'Gebannter', 'Grund', 'Gebannt von', 'Aktiv', 'Aktion'], 'row-bans')}
        ${bans.map((b) => `
          <div class="row row-bans">
            <div>${b.id}</div>
            <div>${escapeHtml(b.user_id)}</div>
            <div>${escapeHtml(b.banned_profile_name || '-')}</div>
            <div>${escapeHtml(b.reason)}</div>
            <div>${escapeHtml(b.banned_by_profile_name || 'System')}</div>
            <div>${b.active ? 'Ja' : 'Nein'}</div>
            <div class="actions">
              ${canManageBans ? `<button class="btn ghost" data-action="unban" data-banid="${b.id}">Entbannen</button>` : ''}
            </div>
          </div>
        `).join('') || renderEmptyRow(bansRaw.length > 0 ? 'Keine Bans für die Suche gefunden.' : 'Keine Bans vorhanden.', 'row-bans')}
      </div>
    </section>
  `;
}

function renderTickets() {
  const tickets = state.data?.tickets || [];
  const canManageTickets = hasPerm('tickets.manage');

  return `
    <section class="card">
      <h3>Spieler-Tickets</h3>
      <div class="list">
        ${rowHeader(['ID', 'Spieler', 'Bearbeitet von', 'Uhrzeit', 'Titel', 'Aktionen'], 'row-ticket')}
        ${tickets.map((t) => `
          <div class="row row-ticket">
            <div>${t.id}</div>
            <div>
              ${escapeHtml(t.creator_name || '-')}
            </div>
            <div>${escapeHtml(t.assigned_name || 'Noch niemand')}</div>
            <div>${escapeHtml(formatDateParts(t.created_at).time)}</div>
            <div>
              ${escapeHtml(t.title)}
            </div>
            <div class="actions">
              ${canManageTickets ? `<button class="btn ghost ticket-action-btn" data-action="ticketClaim" data-ticketid="${t.id}">Beanspruchen</button>` : ''}
              ${canManageTickets ? `<button class="btn ghost ticket-action-btn" data-action="ticketTp" data-ticketid="${t.id}">TP</button>` : ''}
              ${canManageTickets ? `<button class="btn ghost ticket-action-btn" data-action="ticketHeal" data-ticketid="${t.id}">Heilen</button>` : ''}
              ${canManageTickets ? `<button class="btn ghost ticket-action-btn" data-action="ticketRevive" data-ticketid="${t.id}">Revive</button>` : ''}
              ${canManageTickets ? `
                <select class="ticket-status-select" data-ticket-status="${t.id}">
                  <option value="open" ${t.status === 'open' ? 'selected' : ''}>Offen</option>
                  <option value="in_progress" ${t.status === 'in_progress' ? 'selected' : ''}>In Arb.</option>
                  <option value="closed">Schließen (löschen)</option>
                </select>
              ` : ''}
              ${canManageTickets ? `<button class="btn primary ticket-action-btn" data-action="ticketStatus" data-ticketid="${t.id}">Setzen</button>` : ''}
            </div>
          </div>
        `).join('') || renderEmptyRow('Keine Tickets vorhanden.', 'row-ticket')}
      </div>
    </section>
  `;
}

function resolvePermissionGroup(permissionKey) {
  const key = String(permissionKey || '');
  if (key.startsWith('admin.') || key.startsWith('dashboard.')) return 'adminpanel';
  if (key.startsWith('vehicles.') || key === 'commands.repair') return 'auto';
  if (
    key.startsWith('players.')
    || key === 'commands.heal'
    || key === 'commands.revive'
    || key === 'commands.reload'
    || key === 'commands.tp'
    || key === 'commands.tpm'
    || key === 'commands.bring'
    || key === 'commands.freeze'
    || key === 'commands.skin'
    || key === 'commands.noclip'
    || key === 'commands.name'
    || key === 'commands.aduty'
  ) return 'spieler';
  if (key.startsWith('tickets.')) return 'tickets';
  if (key.startsWith('bans.')) return 'bans';
  if (key.startsWith('scripts.')) return 'scripts';
  if (key.startsWith('settings.')) return 'settings';
  if (key.startsWith('rights.')) return 'rechte';
  return 'sonstiges';
}

function renderRights() {
  const roles = state.data?.roles || [];
  const catalog = state.data?.permissionsCatalog || [];
  const matrix = state.data?.rolePermissions || {};
  const roleMembers = state.data?.roleMembers || [];
  const roleDutyOutfits = state.data?.roleDutyOutfits || {};
  const selectedRoleName = getSelectedRightsRole();
  const selectedRole = roles.find((role) => role.role_name === selectedRoleName) || null;
  const selectedRolePerms = new Set(matrix[selectedRoleName] || []);
  const membersForRole = roleMembers.filter((member) => member.roleName === selectedRoleName);
  const selectedDutyOutfit = roleDutyOutfits[selectedRoleName] || { tshirt: 15, top: 15, top2: 0, pants: 14, pants2: 0, shoes: 34, mask: -1 };
  const rolesByImportance = [...roles].sort((a, b) => Number(b.priority || 0) - Number(a.priority || 0));

  if (!state.newRoleInsertAfter) {
    state.newRoleInsertAfter = rolesByImportance[0]?.role_name || '__bottom__';
  }

  const validPositionValues = new Set(['__top__', '__bottom__']);
  for (let i = 0; i < rolesByImportance.length; i += 1) {
    validPositionValues.add(String(rolesByImportance[i].role_name || ''));
  }
  if (!validPositionValues.has(state.newRoleInsertAfter)) {
    state.newRoleInsertAfter = rolesByImportance[0]?.role_name || '__bottom__';
  }

  const createRolePositionOptions = [];
  createRolePositionOptions.push(`<option value="__top__" ${state.newRoleInsertAfter === '__top__' ? 'selected' : ''}>Ganz oben (über allen)</option>`);
  for (let i = 0; i < rolesByImportance.length; i += 1) {
    const upper = rolesByImportance[i];
    const lower = rolesByImportance[i + 1];
    const optionLabel = lower
      ? `Zwischen ${upper.label} und ${lower.label}`
      : `Unterhalb von ${upper.label} (ganz unten)`;
    createRolePositionOptions.push(
      `<option value="${escapeHtml(upper.role_name)}" ${state.newRoleInsertAfter === upper.role_name ? 'selected' : ''}>${escapeHtml(optionLabel)}</option>`
    );
  }
  createRolePositionOptions.push(`<option value="__bottom__" ${state.newRoleInsertAfter === '__bottom__' ? 'selected' : ''}>Ganz unten (unter allen)</option>`);

  const groupLabels = {
    adminpanel: 'Adminpanel',
    auto: 'Auto',
    spieler: 'Spieler',
    tickets: 'Tickets',
    bans: 'Bans',
    scripts: 'Scripts',
    settings: 'Einstellungen',
    rechte: 'Rechte',
    sonstiges: 'Sonstiges'
  };

  const groupOrder = ['adminpanel', 'auto', 'spieler', 'tickets', 'bans', 'scripts', 'settings', 'rechte', 'sonstiges'];
  const groupedPermissions = {};
  for (const groupKey of groupOrder) {
    groupedPermissions[groupKey] = [];
  }
  for (const perm of catalog) {
    const groupKey = resolvePermissionGroup(perm.permission_key);
    if (!groupedPermissions[groupKey]) {
      groupedPermissions[groupKey] = [];
    }
    groupedPermissions[groupKey].push(perm);
  }

  return `
    <section class="grid">
      <div class="card">
        <h3>Neuen Rang erstellen</h3>
        <div class="form-grid" style="margin-bottom:10px;">
          <input id="newRoleLabelInput" type="text" maxlength="48" placeholder="Rangname" />
          <select id="newRolePositionSelect">
            ${createRolePositionOptions.join('')}
          </select>
        </div>
        <div class="actions" style="margin-bottom:12px;">
          <button id="createRoleBtn" class="btn primary" type="button">Rang erstellen</button>
        </div>

        <h3>Rang vergeben</h3>
        <div class="form-grid" style="margin-bottom:10px;">
          <select id="rightsRoleFilter">
            ${roles.map((r) => `<option value="${escapeHtml(r.role_name)}" ${r.role_name === selectedRoleName ? 'selected' : ''}>${escapeHtml(r.label)}</option>`).join('')}
          </select>
          <div class="actions" style="justify-content:flex-end;">
            <button id="deleteRoleBtn" class="btn danger" type="button" ${selectedRoleName === 'projektleitung' ? 'disabled' : ''}>Rang löschen</button>
          </div>
        </div>
        <div class="list">
          ${rowHeader(['User-ID', 'Profilname', 'Rang ändern', 'Aktion'], 'row-rights-members')}
          ${membersForRole.map((member) => `
            <div class="row row-rights-members">
              <div>${escapeHtml(member.userId)}</div>
              <div>${escapeHtml(member.profileName || '-')}</div>
              <div>
                <select data-rights-user-role="${escapeHtml(member.userId)}">
                  <option value="spieler" ${(member.roleName === 'none' || member.roleName === 'spieler' || !member.roleName) ? 'selected' : ''}>Spieler (kein Teamrang)</option>
                  ${roles.map((r) => `<option value="${escapeHtml(r.role_name)}" ${r.role_name === member.roleName ? 'selected' : ''}>${escapeHtml(r.label)}</option>`).join('')}
                </select>
              </div>
              <div class="actions">
                <button class="btn primary" data-action="rightsSaveUserRole" data-userid="${escapeHtml(member.userId)}">Speichern</button>
              </div>
            </div>
          `).join('') || renderEmptyRow('Für diesen Rang gibt es aktuell keine Spieler.', 'row-rights-members')}
        </div>
      </div>

      <div class="card">
        <h3>Rechte für Rang bearbeiten</h3>
        ${groupOrder.map((groupKey) => {
          const groupPerms = groupedPermissions[groupKey] || [];
          if (!groupPerms.length) return '';
          return `
            <h4 style="margin:12px 0 8px;">${escapeHtml(groupLabels[groupKey] || groupKey)}</h4>
            <div class="list" style="margin-bottom:10px;">
              ${rowHeader(['Permission', 'Bezeichnung', 'Erlaubt'], 'row-rights-perms')}
              ${groupPerms.map((p) => `
                <div class="row row-rights-perms">
                  <div>${escapeHtml(p.permission_key)}</div>
                  <div>${escapeHtml(p.label)}</div>
                  <div>
                    <label class="inline-check">
                      <input type="checkbox" data-rights-perm-key="${escapeHtml(p.permission_key)}" ${selectedRolePerms.has(p.permission_key) ? 'checked' : ''} />
                      Aktiv
                    </label>
                  </div>
                </div>
              `).join('')}
            </div>
          `;
        }).join('') || '<div class="muted">Keine Berechtigungen vorhanden.</div>'}
        <div class="actions" style="margin-top:10px;">
          <button id="saveRolePermsBtn" class="btn primary" type="button">Rechte speichern</button>
        </div>
      </div>

      <div class="card">
        <h3>Admin-Duty Outfit pro Rang</h3>
        <p class="muted">Diese Werte werden für <strong>${escapeHtml(selectedRole?.label || '-')}</strong> bei <code>/aduty</code> verwendet.</p>
        <div class="form-grid" style="grid-template-columns: repeat(2, minmax(160px, 1fr)); gap: 10px;">
          <label>
            TShirt 1
            <input id="rightsDutyTshirt" type="number" min="0" max="500" value="${escapeHtml(selectedDutyOutfit.tshirt)}" />
          </label>
          <label>
            Oberteil
            <input id="rightsDutyTop" type="number" min="0" max="500" value="${escapeHtml(selectedDutyOutfit.top)}" />
          </label>
          <label>
            Oberteil 2
            <input id="rightsDutyTop2" type="number" min="0" max="500" value="${escapeHtml(selectedDutyOutfit.top2)}" />
          </label>
          <label>
            Hose
            <input id="rightsDutyPants" type="number" min="0" max="500" value="${escapeHtml(selectedDutyOutfit.pants)}" />
          </label>
          <label>
            Hose 2
            <input id="rightsDutyPants2" type="number" min="0" max="500" value="${escapeHtml(selectedDutyOutfit.pants2)}" />
          </label>
          <label>
            Schuhe
            <input id="rightsDutyShoes" type="number" min="0" max="500" value="${escapeHtml(selectedDutyOutfit.shoes)}" />
          </label>
          <label>
            Maske -1 = aus
            <input id="rightsDutyMask" type="number" min="-1" max="500" value="${escapeHtml(selectedDutyOutfit.mask)}" />
          </label>
        </div>
        <div class="actions" style="margin-top:10px;">
          <button id="saveRoleDutyOutfitBtn" class="btn primary" type="button">Duty-Outfit speichern</button>
        </div>
      </div>
    </section>
  `;
}

function renderScripts() {
  const resourcesRaw = state.data?.resources || [];
  const canRestart = hasPerm('scripts.restart');
  const query = String(state.scriptSearch || '').trim().toLowerCase();
  const resources = query
    ? resourcesRaw.filter((entry) => String(entry.name || '').toLowerCase().includes(query))
    : resourcesRaw;

  return `
    <section class="card">
      <h3>Scripts verwalten</h3>
      <div class="actions" style="margin-bottom:10px;">
        <input id="scriptSearchInput" type="text" placeholder="Script suchen (z. B. rp_bank)" value="${escapeHtml(state.scriptSearch || '')}" />
        <button class="btn primary" id="scriptSearchBtn" type="button">Suchen</button>
        <button class="btn ghost" id="scriptSearchResetBtn" type="button">Zurücksetzen</button>
      </div>
      <div class="list">
        ${rowHeader(['Script', 'Status', 'Aktion'], 'row-scripts')}
        ${resources.map((entry) => `
          <div class="row row-scripts">
            <div>${escapeHtml(entry.name || '-')}</div>
            <div>${escapeHtml(entry.state || 'unknown')}</div>
            <div class="actions">
              ${canRestart ? `<button class="btn ghost" data-action="scriptRestart" data-resource="${escapeHtml(entry.name || '')}">Restart</button>` : ''}
            </div>
          </div>
        `).join('') || renderEmptyRow(resourcesRaw.length > 0 ? 'Keine Scripts für diese Suche.' : 'Keine Scripts gefunden.')}
      </div>
    </section>
  `;
}

function renderSettings() {
  const settings = state.data?.settings || {};
  const canManage = hasPerm('settings.shops.manage');
  const shopsRaw = settings.shops || [];
  const garagesRaw = settings.garages || [];
  const selectedType = String(state.settingsShopType || '').trim();
  const draft = settings.draftCoords || {};
  const garageDraftMarkerCoords = settings.garageDraftMarkerCoords || {};
  const garageDraftSpawnCoords = settings.garageDraftSpawnCoords || {};
  const typeLabels = {
    '24_7': '24/7 Shop',
    vehicle: 'Autohaus',
    clothing: 'Kleidungsshop',
    garage: 'Garagen'
  };

  if (!selectedType) {
    const byTypeCount = {
      '24_7': shopsRaw.filter((shop) => String(shop.shop_type) === '24_7').length,
      vehicle: shopsRaw.filter((shop) => String(shop.shop_type) === 'vehicle').length,
      clothing: shopsRaw.filter((shop) => String(shop.shop_type) === 'clothing').length,
      garage: garagesRaw.length
    };

    return `
      <section class="card">
        <h3>Einstellungen: Bereich auswählen</h3>
        <p class="muted">Doppelklick auf einen Bereich, um die Verwaltung zu öffnen.</p>
        <div class="settings-type-grid">
          <div class="settings-type-card" data-action="selectSettingsType" data-type="24_7">
            <h4>24/7 Shops</h4>
            <p>${byTypeCount['24_7']} vorhanden</p>
          </div>
          <div class="settings-type-card" data-action="selectSettingsType" data-type="vehicle">
            <h4>Autohäuser</h4>
            <p>${byTypeCount.vehicle} vorhanden</p>
          </div>
          <div class="settings-type-card" data-action="selectSettingsType" data-type="clothing">
            <h4>Kleidungsläden</h4>
            <p>${byTypeCount.clothing} vorhanden</p>
          </div>
          <div class="settings-type-card" data-action="selectSettingsType" data-type="garage">
            <h4>Garagen</h4>
            <p>${byTypeCount.garage} vorhanden</p>
          </div>
        </div>
      </section>
    `;
  }

  const query = String(state.shopSearch || '').trim().toLowerCase();
  if (selectedType === 'garage') {
    const garages = query
      ? garagesRaw.filter((garage) => {
        const line = `${garage.id || ''} ${garage.garage_code || ''} ${garage.label || ''}`.toLowerCase();
        return line.includes(query);
      })
      : garagesRaw;

    return `
      <section class="grid">
        <div class="card">
          <h3>Garagen</h3>
          <div class="actions" style="margin-bottom:10px;">
            <button class="btn ghost" id="settingsBackBtn" type="button">Zurück zur Bereichsauswahl</button>
            <input id="shopSearchInput" type="text" placeholder="Suchen (ID, Code, Name)" value="${escapeHtml(state.shopSearch || '')}" />
            <button class="btn primary" id="shopSearchBtn" type="button">Suchen</button>
            <button class="btn ghost" id="shopSearchResetBtn" type="button">Zurücksetzen</button>
          </div>
          <div class="list">
            ${rowHeader(['ID', 'Code', 'Name', 'Blip', 'Marker', 'Spawn', 'Aktion'], 'row-settings-garages')}
            ${garages.map((garage) => `
              <div class="row row-settings-garages" data-action="openGarageEditModal" data-garageid="${escapeHtml(garage.id)}">
                <div>${escapeHtml(garage.id)}</div>
                <div>${escapeHtml(garage.garage_code || '-')}</div>
                <div>${escapeHtml(garage.label || '-')}</div>
                <div>${Number(garage.blip_enabled) === 1 ? 'Ja' : 'Nein'}</div>
                <div>${formatCoord(garage.pos_x)}, ${formatCoord(garage.pos_y)}, ${formatCoord(garage.pos_z)}</div>
                <div>${formatCoord(garage.spawn_x)}, ${formatCoord(garage.spawn_y)}, ${formatCoord(garage.spawn_z)} | ${formatCoord(garage.spawn_heading)}</div>
                <div class="actions">
                  <button class="btn ghost" data-action="openGarageEditModal" data-garageid="${escapeHtml(garage.id)}">Bearbeiten</button>
                </div>
              </div>
            `).join('') || renderEmptyRow(garagesRaw.length > 0 ? 'Keine Garagen für diese Suche.' : 'Noch keine Garagen vorhanden.', 'row-settings-garages')}
          </div>
        </div>

        <div class="card">
          <h3>Neue Garage erstellen</h3>
          <div class="form-grid">
            <input id="newGarageLabel" type="text" placeholder="Garagenname" />
            <input id="newGarageCode" type="text" placeholder="Garage-Code (optional)" />
            <div class="actions">
              <label class="inline-check"><input id="newGarageBlipEnabled" type="checkbox" checked /> Blip anzeigen</label>
              <label class="inline-check"><input id="newGarageEnabled" type="checkbox" checked /> Aktiv</label>
            </div>
            <label class="muted">Marker (Einparken/Ausparken)</label>
            <input id="newGarageX" type="number" step="0.01" placeholder="Marker X" value="${escapeHtml(garageDraftMarkerCoords.x ?? '')}" />
            <input id="newGarageY" type="number" step="0.01" placeholder="Marker Y" value="${escapeHtml(garageDraftMarkerCoords.y ?? '')}" />
            <input id="newGarageZ" type="number" step="0.01" placeholder="Marker Z" value="${escapeHtml(garageDraftMarkerCoords.z ?? '')}" />
            <label class="muted">Spawn</label>
            <input id="newGarageSpawnX" type="number" step="0.01" placeholder="Spawn X" value="${escapeHtml(garageDraftSpawnCoords.x ?? '')}" />
            <input id="newGarageSpawnY" type="number" step="0.01" placeholder="Spawn Y" value="${escapeHtml(garageDraftSpawnCoords.y ?? '')}" />
            <input id="newGarageSpawnZ" type="number" step="0.01" placeholder="Spawn Z" value="${escapeHtml(garageDraftSpawnCoords.z ?? '')}" />
            <input id="newGarageSpawnH" type="number" step="0.01" placeholder="Spawn Heading" value="${escapeHtml(garageDraftSpawnCoords.h ?? '')}" />
          </div>
          <div class="actions" style="margin-top:10px;">
            ${canManage ? `<button class="btn ghost" id="useCurrentGarageMarkerCoordsBtn" type="button">Marker von aktueller Position</button>` : ''}
            ${canManage ? `<button class="btn ghost" id="useCurrentGarageSpawnCoordsBtn" type="button">Spawn von aktueller Position</button>` : ''}
            ${canManage ? `<button class="btn primary" id="createGarageBtn" type="button">Garage erstellen</button>` : ''}
          </div>
        </div>
      </section>
    `;
  }

  const filteredByType = shopsRaw.filter((shop) => String(shop.shop_type) === selectedType);
  const shops = query
    ? filteredByType.filter((shop) => {
      const line = `${shop.id || ''} ${shop.shop_code || ''} ${shop.label || ''} ${shop.shop_type || ''}`.toLowerCase();
      return line.includes(query);
    })
    : filteredByType;

  const is247 = selectedType === '24_7';
  const isVehicle = selectedType === 'vehicle';
  const isClothing = selectedType === 'clothing';

  return `
    <section class="grid">
      <div class="card">
        <h3>${escapeHtml(typeLabels[selectedType] || 'Shops')}</h3>
        <div class="actions" style="margin-bottom:10px;">
          <button class="btn ghost" id="settingsBackBtn" type="button">Zurück zur Bereichsauswahl</button>
          <input id="shopSearchInput" type="text" placeholder="Suchen (ID, Code, Name)" value="${escapeHtml(state.shopSearch || '')}" />
          <button class="btn primary" id="shopSearchBtn" type="button">Suchen</button>
          <button class="btn ghost" id="shopSearchResetBtn" type="button">Zurücksetzen</button>
        </div>
        <div class="list">
          ${rowHeader(['ID', 'Code', 'Name', 'Typ', 'Blip', 'Koordinaten', 'Aktion'], 'row-settings-shops')}
          ${shops.map((shop) => `
            <div class="row row-settings-shops" data-action="openShopEditModal" data-shopid="${escapeHtml(shop.id)}">
              <div>${escapeHtml(shop.id)}</div>
              <div>${escapeHtml(shop.shop_code)}</div>
              <div>${escapeHtml(shop.label)}</div>
              <div>${escapeHtml(getShopTypeLabel(shop.shop_type))}</div>
              <div>${Number(shop.blip_enabled) === 1 ? 'Ja' : 'Nein'}</div>
              <div>${formatCoord(shop.pos_x)}, ${formatCoord(shop.pos_y)}, ${formatCoord(shop.pos_z)}</div>
              <div class="actions">
                ${is247 ? `<button class="btn ghost" data-action="openShopItemsModal" data-shopid="${escapeHtml(shop.id)}">Items</button>` : ''}
                ${isVehicle ? `<button class="btn ghost" data-action="openShopVehiclesModal" data-shopid="${escapeHtml(shop.id)}">Fahrzeuge</button>` : ''}
                <button class="btn ghost" data-action="openShopEditModal" data-shopid="${escapeHtml(shop.id)}">Bearbeiten</button>
              </div>
            </div>
          `).join('') || renderEmptyRow(filteredByType.length > 0 ? 'Keine Shops für diese Suche.' : 'Keine Shops in diesem Bereich vorhanden.')}
        </div>
      </div>

      <div class="card">
        <h3>Neuen ${escapeHtml(typeLabels[selectedType] || 'Shop')} erstellen</h3>
        <div class="form-grid">
          ${isClothing ? '' : `<input id="newShopLabel" type="text" placeholder="Shop-Name" />`}
          ${isClothing ? '' : `<input id="newShopCode" type="text" placeholder="Shop-Code (optional)" />`}
          <input id="newShopType" type="text" value="${escapeHtml(selectedType)}" readonly />
          ${isClothing ? `<label class="muted">Beim Kleidungsshop werden nur die Positionspunkte verwendet.</label>` : `
          <div class="actions">
            <label class="inline-check"><input id="newShopBlipEnabled" type="checkbox" checked /> Blip anzeigen</label>
            <label class="inline-check"><input id="newShopEnabled" type="checkbox" checked /> Aktiv</label>
          </div>`}
          <input id="newShopX" type="number" step="0.01" placeholder="X" value="${escapeHtml(draft.x ?? '')}" />
          <input id="newShopY" type="number" step="0.01" placeholder="Y" value="${escapeHtml(draft.y ?? '')}" />
          <input id="newShopZ" type="number" step="0.01" placeholder="Z" value="${escapeHtml(draft.z ?? '')}" />
          <input id="newShopH" type="number" step="0.01" placeholder="Heading" value="${escapeHtml(draft.h ?? '')}" />
          ${isVehicle ? `
          <label class="muted">Optional: Erstes Fahrzeug direkt hinzufügen</label>
          <select id="newShopVehicleId">
            <option value="">Kein Fahrzeug</option>
            ${(settings.vehicleCatalog || []).filter((v) => Number(v.enabled) === 1).map((vehicle) => `
              <option value="${escapeHtml(vehicle.id)}" data-price="${escapeHtml(vehicle.price)}">
                ${escapeHtml(vehicle.label)} (${escapeHtml(vehicle.model)})
              </option>
            `).join('')}
          </select>
          <input id="newShopVehiclePrice" type="number" min="0" step="1" placeholder="Preis Fahrzeug" value="" />
          ` : ''}
        </div>
        <div class="actions" style="margin-top:10px;">
          ${canManage ? `<button class="btn ghost" id="useCurrentShopCoordsBtn" type="button">Aktuelle Position übernehmen</button>` : ''}
          ${canManage ? `<button class="btn primary" id="createShopBtn" type="button">Shop erstellen</button>` : ''}
        </div>
      </div>
    </section>
  `;
}

function renderTicketPortal() {
  const tickets = state.data?.tickets || [];
  const ownName = state.data?.viewer?.displayName || 'Spieler';
  const ownOpen = state.data?.stats?.ownOpenTickets || 0;

  return `
    <section class="grid two">
      <div class="card">
        <h3>Support-Ticket erstellen</h3>
        <p class="muted">Hallo ${escapeHtml(ownName)}. Beschreibe dein Anliegen so genau wie möglich.</p>
        <div class="kpis" style="grid-template-columns: 1fr;">
          <div class="kpi"><div class="label">Deine offenen Tickets</div><div class="value">${ownOpen}</div></div>
        </div>
        <div class="form-grid full" style="margin-top:10px;">
          <input id="playerTicketTitle" type="text" placeholder="Kurzer Titel (optional)" />
          <textarea id="playerTicketDescription" placeholder="Worum geht es genau?"></textarea>
        </div>
        <div class="actions" style="margin-top:10px;">
          <button id="playerCreateTicketBtn" class="btn primary" type="button">Ticket absenden</button>
          <button id="playerRefreshTicketsBtn" class="btn ghost" type="button">Aktualisieren</button>
        </div>
      </div>

      <div class="card">
        <h3>Deine Tickets</h3>
        <div class="list">
          ${rowHeader(['ID', 'Status', 'Titel', 'Bearbeitet von', 'Erstellt', ''])}
          ${tickets.map((t) => `
            <div class="row">
              <div>${t.id}</div>
              <div>${escapeHtml(renderTicketStatus(t.status))}</div>
              <div>
                ${escapeHtml(t.title)}
                <span class="mini">${escapeHtml(t.description || '')}</span>
              </div>
              <div>${escapeHtml(t.assigned_name || 'Noch niemand')}</div>
              <div>${escapeHtml(formatDateTime(t.created_at))}</div>
              <div></div>
            </div>
          `).join('') || '<div class="row"><div class="muted">Du hast noch keine Tickets erstellt.</div></div>'}
        </div>
      </div>
    </section>
  `;
}

function renderContent() {
  if (!state.data) {
    return '<section class="card"><p>Lade Daten ...</p></section>';
  }

  if (state.mode === 'ticket') {
    return renderTicketPortal();
  }

  switch (state.activeTab) {
    case 'players': return renderPlayers();
    case 'bans': return renderBans();
    case 'tickets': return renderTickets();
    case 'rights': return renderRights();
    case 'scripts': return renderScripts();
    case 'settings': return renderSettings();
    default: return renderDashboard();
  }
}

function bindCommonActions() {
  const searchBtn = document.getElementById('searchBtn');
  if (searchBtn) {
    searchBtn.addEventListener('click', async () => {
      const query = document.getElementById('playerSearch')?.value || '';
      await post('players.search', { query });
      setFooter('Spielersuche angefragt ...');
    });
  }

  const playerSearchInput = document.getElementById('playerSearch');
  if (playerSearchInput) {
    playerSearchInput.addEventListener('keydown', async (event) => {
      if (event.key !== 'Enter') return;
      const query = playerSearchInput.value || '';
      await post('players.search', { query });
      setFooter('Spielersuche angefragt ...');
    });
  }

  const refreshBtn = document.getElementById('refreshBtn');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', async () => {
      await post('refresh', {});
      setFooter('Aktualisierung angefragt ...');
    });
  }

  const playerModeSelect = document.getElementById('playerModeSelect');
  if (playerModeSelect) {
    playerModeSelect.addEventListener('change', async () => {
      const mode = playerModeSelect.value === 'offline' ? 'offline' : 'live';
      await post('players.mode', { mode });
      setFooter(`Spieleransicht auf ${mode === 'offline' ? 'Offline' : 'Live'} gesetzt ...`);
    });
  }

  const banSearchBtn = document.getElementById('banSearchBtn');
  if (banSearchBtn) {
    banSearchBtn.addEventListener('click', () => {
      const query = document.getElementById('banSearch')?.value || '';
      state.banSearch = query.trim();
      render();
      setFooter('Ban-Suche aktualisiert.');
    });
  }

  const banSearchInput = document.getElementById('banSearch');
  if (banSearchInput) {
    banSearchInput.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      state.banSearch = (banSearchInput.value || '').trim();
      render();
      setFooter('Ban-Suche aktualisiert.');
    });
  }

  const banSearchResetBtn = document.getElementById('banSearchResetBtn');
  if (banSearchResetBtn) {
    banSearchResetBtn.addEventListener('click', () => {
      state.banSearch = '';
      render();
      setFooter('Ban-Suche zurückgesetzt.');
    });
  }

  const scriptSearchBtn = document.getElementById('scriptSearchBtn');
  if (scriptSearchBtn) {
    scriptSearchBtn.addEventListener('click', () => {
      state.scriptSearch = (document.getElementById('scriptSearchInput')?.value || '').trim();
      render();
      setFooter('Script-Suche aktualisiert.');
    });
  }

  const scriptSearchInput = document.getElementById('scriptSearchInput');
  if (scriptSearchInput) {
    scriptSearchInput.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      state.scriptSearch = (scriptSearchInput.value || '').trim();
      render();
      setFooter('Script-Suche aktualisiert.');
    });
  }

  const scriptSearchResetBtn = document.getElementById('scriptSearchResetBtn');
  if (scriptSearchResetBtn) {
    scriptSearchResetBtn.addEventListener('click', () => {
      state.scriptSearch = '';
      render();
      setFooter('Script-Suche zurückgesetzt.');
    });
  }

  const shopSearchBtn = document.getElementById('shopSearchBtn');
  if (shopSearchBtn) {
    shopSearchBtn.addEventListener('click', () => {
      state.shopSearch = (document.getElementById('shopSearchInput')?.value || '').trim();
      render();
      setFooter('Shop-Suche aktualisiert.');
    });
  }

  const shopSearchInput = document.getElementById('shopSearchInput');
  if (shopSearchInput) {
    shopSearchInput.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      state.shopSearch = (shopSearchInput.value || '').trim();
      render();
      setFooter('Shop-Suche aktualisiert.');
    });
  }

  const shopSearchResetBtn = document.getElementById('shopSearchResetBtn');
  if (shopSearchResetBtn) {
    shopSearchResetBtn.addEventListener('click', () => {
      state.shopSearch = '';
      render();
      setFooter('Shop-Suche zurückgesetzt.');
    });
  }

  const settingsBackBtn = document.getElementById('settingsBackBtn');
  if (settingsBackBtn) {
    settingsBackBtn.addEventListener('click', () => {
      state.settingsShopType = '';
      state.shopSearch = '';
      render();
      setFooter('Bereichsauswahl geöffnet.');
    });
  }

  const rightsRoleFilter = document.getElementById('rightsRoleFilter');
  if (rightsRoleFilter) {
    rightsRoleFilter.addEventListener('change', () => {
      state.rightsSelectedRole = rightsRoleFilter.value || '';
      render();
    });
  }

  const createRoleBtn = document.getElementById('createRoleBtn');
  const newRolePositionSelect = document.getElementById('newRolePositionSelect');
  if (newRolePositionSelect) {
    newRolePositionSelect.addEventListener('change', () => {
      state.newRoleInsertAfter = String(newRolePositionSelect.value || '__bottom__');
    });
  }

  if (createRoleBtn) {
    createRoleBtn.addEventListener('click', async () => {
      const labelInput = document.getElementById('newRoleLabelInput');
      const label = (labelInput?.value || '').trim();
      const insertAfterRoleName = String(newRolePositionSelect?.value || state.newRoleInsertAfter || '__bottom__');
      if (!label) {
        setFooter('Bitte gib zuerst einen Rangnamen ein.');
        return;
      }

      await post('rights.createRole', { label, insertAfterRoleName });
      if (labelInput) {
        labelInput.value = '';
      }
      setFooter(`Rang "${label}" wird erstellt ...`);
    });
  }

  const deleteRoleBtn = document.getElementById('deleteRoleBtn');
  if (deleteRoleBtn) {
    deleteRoleBtn.addEventListener('click', async () => {
      const roleName = getSelectedRightsRole();
      if (!roleName) {
        setFooter('Kein Rang ausgewählt.');
        return;
      }
      if (roleName === 'projektleitung') {
        setFooter('Projektleitung kann nicht gelöscht werden.');
        return;
      }

      const selectedRole = (state.data?.roles || []).find((r) => r.role_name === roleName);
      const roleLabel = selectedRole?.label || roleName;
      openConfirmModal({
        title: 'Rang löschen',
        text: `Rang "${roleLabel}" wirklich löschen?`,
        confirmLabel: 'Löschen',
        onConfirm: async () => {
          await post('rights.deleteRole', { roleName });
          setFooter(`Rang "${roleLabel}" wird gelöscht ...`);
        }
      });
    });
  }

  const saveRolePermsBtn = document.getElementById('saveRolePermsBtn');
  if (saveRolePermsBtn) {
    saveRolePermsBtn.addEventListener('click', async () => {
      const roleName = getSelectedRightsRole();
      const permissionKeys = Array.from(contentEl.querySelectorAll('input[data-rights-perm-key]:checked'))
        .map((el) => String(el.getAttribute('data-rights-perm-key') || '').trim())
        .filter((key) => key.length > 0);

      await post('rights.setRolePermissions', { roleName, permissionKeys });
      setFooter(`Rechte für Rang "${roleName}" werden gespeichert ...`);
    });
  }

  const saveRoleDutyOutfitBtn = document.getElementById('saveRoleDutyOutfitBtn');
  if (saveRoleDutyOutfitBtn) {
    saveRoleDutyOutfitBtn.addEventListener('click', async () => {
      const roleName = getSelectedRightsRole();
      const values = {
        tshirt: Number(document.getElementById('rightsDutyTshirt')?.value ?? 15),
        top: Number(document.getElementById('rightsDutyTop')?.value ?? 15),
        top2: Number(document.getElementById('rightsDutyTop2')?.value ?? 0),
        pants: Number(document.getElementById('rightsDutyPants')?.value ?? 14),
        pants2: Number(document.getElementById('rightsDutyPants2')?.value ?? 0),
        shoes: Number(document.getElementById('rightsDutyShoes')?.value ?? 34),
        mask: Number(document.getElementById('rightsDutyMask')?.value ?? -1)
      };

      await post('rights.setRoleDutyOutfit', { roleName, values });
      setFooter(`Duty-Outfit für Rang "${roleName}" wird gespeichert ...`);
    });
  }

  contentEl.querySelectorAll('[data-action="rightsSaveUserRole"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const targetUserId = Number(el.dataset.userid || 0);
      const select = contentEl.querySelector(`select[data-rights-user-role="${targetUserId}"]`);
      const roleName = select?.value || '';
      await post('rights.assignRole', { targetUserId, roleName });
      setFooter(`Rangänderung für User ${targetUserId} gesendet ...`);
    });
  });

  contentEl.querySelectorAll('[data-action="scriptRestart"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const resourceName = String(el.dataset.resource || '').trim();
      if (!resourceName) return;
      await post('scripts.restart', { resourceName });
      setFooter(`Restart von ${resourceName} gesendet ...`);
    });
  });

  contentEl.querySelectorAll('[data-action="openShopItemsModal"]').forEach((el) => {
    el.addEventListener('click', () => {
      const shopId = Number(el.dataset.shopid || 0);
      if (!shopId) return;
      openShopItemsModal(shopId);
    });
  });

  contentEl.querySelectorAll('[data-action="openShopVehiclesModal"]').forEach((el) => {
    el.addEventListener('click', () => {
      const shopId = Number(el.dataset.shopid || 0);
      if (!shopId) return;
      openShopVehiclesModal(shopId);
    });
  });

  contentEl.querySelectorAll('[data-action="openShopEditModal"]').forEach((el) => {
    el.addEventListener('dblclick', () => {
      const shopId = Number(el.dataset.shopid || 0);
      if (!shopId) return;
      openShopEditModal(shopId);
    });
    el.addEventListener('click', (event) => {
      const target = event.target;
      if (target && target.closest('button')) return;
      const shopId = Number(el.dataset.shopid || 0);
      if (!shopId) return;
      openShopEditModal(shopId);
    });
  });

  contentEl.querySelectorAll('[data-action="openGarageEditModal"]').forEach((el) => {
    el.addEventListener('dblclick', () => {
      const garageId = Number(el.dataset.garageid || 0);
      if (!garageId) return;
      openGarageEditModal(garageId);
    });
    el.addEventListener('click', (event) => {
      const target = event.target;
      if (target && target.closest('button')) return;
      const garageId = Number(el.dataset.garageid || 0);
      if (!garageId) return;
      openGarageEditModal(garageId);
    });
  });

  contentEl.querySelectorAll('[data-action="selectSettingsType"]').forEach((el) => {
    const openType = () => {
      state.settingsShopType = String(el.dataset.type || '').trim();
      state.shopSearch = '';
      render();
      setFooter(`${getShopTypeLabel(state.settingsShopType)} geöffnet.`);
    };
    el.addEventListener('dblclick', openType);
    el.addEventListener('click', openType);
  });

  const useCurrentShopCoordsBtn = document.getElementById('useCurrentShopCoordsBtn');
  if (useCurrentShopCoordsBtn) {
    useCurrentShopCoordsBtn.addEventListener('click', async () => {
      await post('settings.shops.useCurrentCoords', {});
      setFooter('Aktuelle Position wird übernommen ...');
    });
  }

  const createShopBtn = document.getElementById('createShopBtn');
  if (createShopBtn) {
    createShopBtn.addEventListener('click', async () => {
      const selectedType = document.getElementById('newShopType')?.value || state.settingsShopType || '24_7';
      const vehicleId = Number(document.getElementById('newShopVehicleId')?.value || 0);
      const vehiclePrice = Number(document.getElementById('newShopVehiclePrice')?.value || 0);
      const isClothing = selectedType === 'clothing';
      const payload = {
        label: document.getElementById('newShopLabel')?.value || '',
        shopCode: document.getElementById('newShopCode')?.value || '',
        shopType: selectedType,
        blipEnabled: isClothing ? false : (document.getElementById('newShopBlipEnabled')?.checked !== false),
        enabled: isClothing ? true : (document.getElementById('newShopEnabled')?.checked !== false),
        coords: {
          x: parseNullableNumber(document.getElementById('newShopX')?.value),
          y: parseNullableNumber(document.getElementById('newShopY')?.value),
          z: parseNullableNumber(document.getElementById('newShopZ')?.value),
          h: parseNullableNumber(document.getElementById('newShopH')?.value)
        },
        vehicleEntries: (selectedType === 'vehicle' && vehicleId > 0)
          ? [{ vehicleId, price: Number.isFinite(vehiclePrice) ? vehiclePrice : 0 }]
          : []
      };

      await post('settings.shops.create', payload);
      setFooter('Shop wird erstellt ...');
    });
  }

  const useCurrentGarageMarkerCoordsBtn = document.getElementById('useCurrentGarageMarkerCoordsBtn');
  if (useCurrentGarageMarkerCoordsBtn) {
    useCurrentGarageMarkerCoordsBtn.addEventListener('click', async () => {
      await post('settings.garages.useCurrentMarkerCoords', {});
      setFooter('Aktuelle Position wird als Garage-Marker übernommen ...');
    });
  }

  const useCurrentGarageSpawnCoordsBtn = document.getElementById('useCurrentGarageSpawnCoordsBtn');
  if (useCurrentGarageSpawnCoordsBtn) {
    useCurrentGarageSpawnCoordsBtn.addEventListener('click', async () => {
      await post('settings.garages.useCurrentSpawnCoords', {});
      setFooter('Aktuelle Position wird als Garage-Spawn übernommen ...');
    });
  }

  const createGarageBtn = document.getElementById('createGarageBtn');
  if (createGarageBtn) {
    createGarageBtn.addEventListener('click', async () => {
      const payload = {
        label: document.getElementById('newGarageLabel')?.value || '',
        garageCode: document.getElementById('newGarageCode')?.value || '',
        blipEnabled: (document.getElementById('newGarageBlipEnabled')?.checked !== false),
        enabled: (document.getElementById('newGarageEnabled')?.checked !== false),
        markerCoords: {
          x: parseNullableNumber(document.getElementById('newGarageX')?.value),
          y: parseNullableNumber(document.getElementById('newGarageY')?.value),
          z: parseNullableNumber(document.getElementById('newGarageZ')?.value)
        },
        spawnCoords: {
          x: parseNullableNumber(document.getElementById('newGarageSpawnX')?.value),
          y: parseNullableNumber(document.getElementById('newGarageSpawnY')?.value),
          z: parseNullableNumber(document.getElementById('newGarageSpawnZ')?.value),
          h: parseNullableNumber(document.getElementById('newGarageSpawnH')?.value)
        }
      };

      await post('settings.garages.create', payload);
      setFooter('Garage wird erstellt ...');
    });
  }

  const newShopVehicleSelect = document.getElementById('newShopVehicleId');
  const newShopVehiclePrice = document.getElementById('newShopVehiclePrice');
  if (newShopVehicleSelect && newShopVehiclePrice) {
    const syncPrice = () => {
      const opt = newShopVehicleSelect.options[newShopVehicleSelect.selectedIndex];
      const fallback = Number(opt?.dataset?.price || 0);
      if (fallback >= 0) {
        newShopVehiclePrice.value = String(fallback);
      }
    };
    newShopVehicleSelect.addEventListener('change', syncPrice);
    syncPrice();
  }

}

function bindAdminActions() {
  bindCommonActions();

  contentEl.querySelectorAll('.player-row[data-action="openPlayerModal"]').forEach((rowEl) => {
    rowEl.addEventListener('dblclick', () => {
      const player = {
        source: Number(rowEl.dataset.source || 0),
        userId: Number(rowEl.dataset.userid || 0) || null,
        name: rowEl.dataset.name || '',
        characterName: rowEl.dataset.character || '',
        roleName: rowEl.dataset.roleName || 'none',
        roleLabel: rowEl.dataset.roleLabel || 'Kein Rang',
        online: rowEl.dataset.online === '1'
      };
      openPlayerManageModal(player);
    });
  });

  contentEl.querySelectorAll('[data-action="kick"]').forEach((el) => {
    el.addEventListener('click', (event) => {
      event.stopPropagation();
      const targetSource = Number(el.dataset.source || 0);
      const targetUserId = Number(el.dataset.userid || 0);
      const targetName = el.dataset.name || 'Spieler';
      const isOnline = el.dataset.online === '1';
      openPlayerActionModal('kick', {
        targetSource,
        targetUserId,
        targetName,
        isOnline
      });
    });
  });

  contentEl.querySelectorAll('[data-action="ban"]').forEach((el) => {
    el.addEventListener('click', (event) => {
      event.stopPropagation();
      const targetSource = Number(el.dataset.source || 0);
      const targetUserId = Number(el.dataset.userid || 0);
      const targetName = el.dataset.name || 'Spieler';
      const isOnline = el.dataset.online === '1';
      openPlayerActionModal('ban', {
        targetSource,
        targetUserId,
        targetName,
        isOnline
      });
    });
  });

  contentEl.querySelectorAll('[data-action="unban"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const banId = Number(el.dataset.banid || 0);
      await post('bans.revoke', { banId });
    });
  });

  contentEl.querySelectorAll('[data-action="ticketStatus"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const ticketId = Number(el.dataset.ticketid || 0);
      const select = contentEl.querySelector(`select[data-ticket-status="${ticketId}"]`);
      const status = select?.value || 'open';
      await post('tickets.status', { ticketId, status });
    });
  });

  contentEl.querySelectorAll('[data-action="ticketClaim"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const ticketId = Number(el.dataset.ticketid || 0);
      openTicketPreview(ticketId);
    });
  });

  contentEl.querySelectorAll('[data-action="ticketTp"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const ticketId = Number(el.dataset.ticketid || 0);
      await post('tickets.tp', { ticketId });
    });
  });

  contentEl.querySelectorAll('[data-action="ticketHeal"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const ticketId = Number(el.dataset.ticketid || 0);
      await post('tickets.heal', { ticketId });
    });
  });

  contentEl.querySelectorAll('[data-action="ticketRevive"]').forEach((el) => {
    el.addEventListener('click', async () => {
      const ticketId = Number(el.dataset.ticketid || 0);
      await post('tickets.revive', { ticketId });
    });
  });
}

function bindTicketPortalActions() {
  const createBtn = document.getElementById('playerCreateTicketBtn');
  if (createBtn) {
    createBtn.addEventListener('click', async () => {
      const title = document.getElementById('playerTicketTitle')?.value || '';
      const description = document.getElementById('playerTicketDescription')?.value || '';
      await post('ticket.create', { title, description });
      setFooter('Ticket wird gesendet ...');
    });
  }

  const refreshBtn = document.getElementById('playerRefreshTicketsBtn');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', async () => {
      await post('ticket.refresh', {});
      setFooter('Tickets werden aktualisiert ...');
    });
  }
}

function render() {
  if (!state.visible) return;

  app.classList.toggle('ticket-mode', state.mode === 'ticket');
  renderTabs();
  contentEl.innerHTML = renderContent();

  if (state.mode === 'admin') {
    panelTitleEl.textContent = 'PrimeCity Admin Panel';
    viewerRoleEl.textContent = state.data?.viewer?.roleLabel || 'Kein Rang';
    bindAdminActions();
  } else {
    panelTitleEl.textContent = 'PrimeCity Support';
    viewerRoleEl.textContent = 'Spieler';
    bindTicketPortalActions();
  }
}

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};

  if (action === 'open') {
    setVisible(true);
    return;
  }

  if (action === 'close') {
    setVisible(false);
    return;
  }

  if (action === 'setData') {
    state.data = data;
    state.mode = data?.mode === 'ticket' ? 'ticket' : 'admin';
    setVisible(true);
    render();
    setFooter(`Zuletzt aktualisiert: ${new Date().toLocaleTimeString('de-DE')}`);
    return;
  }

  if (action === 'notify' && data?.message) {
    setFooter(data.message);
  }
});

closeBtn.addEventListener('click', async () => {
  await fetch(`https://${GetParentResourceName()}/admin:close`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({})
  });
});
