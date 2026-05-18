const hud = document.getElementById('hud');
const veh = document.getElementById('veh');
const editHint = document.getElementById('editHint');

const nameEl = document.getElementById('name');
const cashEl = document.getElementById('cash');
const bankEl = document.getElementById('bank');
const jobEl = document.getElementById('job');
const timeEl = document.getElementById('time');

const speedEl = document.getElementById('speed');
const gearEl = document.getElementById('gear');
const engineEl = document.getElementById('engine');
const fuelEl = document.getElementById('fuel');

const fmtMoney = (v) => `${Number(v || 0).toLocaleString('de-DE')}$`;

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rp_hud';

let editMode = false;
let dragActive = false;
let dragOffsetX = 0;
let dragOffsetY = 0;
let layout = { x: null, y: null };

function applyLayout(normalizedX, normalizedY) {
  const x = clamp(Number(normalizedX), 0.01, 0.99);
  const y = clamp(Number(normalizedY), 0.01, 0.99);

  layout.x = x;
  layout.y = y;

  hud.style.left = `${(x * 100).toFixed(4)}vw`;
  hud.style.top = `${(y * 100).toFixed(4)}vh`;
  hud.style.bottom = 'auto';
}

function setDefaultLayoutFromCurrentPosition() {
  if (layout.x != null && layout.y != null) {
    return;
  }

  const rect = hud.getBoundingClientRect();
  const x = rect.left / Math.max(window.innerWidth, 1);
  const y = rect.top / Math.max(window.innerHeight, 1);
  applyLayout(x, y);
}

function saveLayout() {
  if (layout.x == null || layout.y == null) {
    return;
  }

  fetch(`https://${resourceName}/hud:saveLayout`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({ x: layout.x, y: layout.y })
  }).catch(() => {});
}

function setEditMode(enabled) {
  editMode = enabled === true;
  dragActive = false;
  hud.classList.toggle('edit-mode', editMode);
  editHint.classList.toggle('hidden', !editMode);
}

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};

  if (action === 'show') {
    hud.classList.remove('hidden');
    return;
  }

  if (action === 'hide') {
    hud.classList.add('hidden');
    veh.classList.add('hidden');
    return;
  }

  if (action === 'setLayout') {
    if (typeof data?.x === 'number' && typeof data?.y === 'number') {
      applyLayout(data.x, data.y);
    }
    return;
  }

  if (action === 'setEditMode') {
    setDefaultLayoutFromCurrentPosition();
    setEditMode(data?.enabled === true);
    return;
  }

  if (action === 'updateHud') {
    nameEl.textContent = data.fullName || 'Unbekannt';
    cashEl.textContent = fmtMoney(data.cash);
    bankEl.textContent = fmtMoney(data.bank);
    jobEl.textContent = data.onDuty ? `${data.job} (im Dienst)` : `${data.job}`;
    timeEl.textContent = data.time || '00:00';
    return;
  }

  if (action === 'updateVehicle') {
    if (!data.inVehicle) {
      veh.classList.add('hidden');
      return;
    }

    veh.classList.remove('hidden');
    speedEl.textContent = `${Number(data.speed || 0)} km/h`;
    gearEl.textContent = Number(data.gear || 0) <= 0 ? 'N' : String(data.gear);
    engineEl.textContent = data.engine ? 'An' : 'Aus';
    fuelEl.textContent = data.fuel == null ? '-' : `${Math.round(data.fuel)}%`;
  }
});

hud.addEventListener('mousedown', (event) => {
  if (!editMode || event.button !== 0) {
    return;
  }

  const rect = hud.getBoundingClientRect();
  dragOffsetX = event.clientX - rect.left;
  dragOffsetY = event.clientY - rect.top;
  dragActive = true;
  event.preventDefault();
});

window.addEventListener('mousemove', (event) => {
  if (!editMode || !dragActive) {
    return;
  }

  const width = hud.offsetWidth;
  const height = hud.offsetHeight;

  const leftPx = clamp(event.clientX - dragOffsetX, 0, Math.max(0, window.innerWidth - width));
  const topPx = clamp(event.clientY - dragOffsetY, 0, Math.max(0, window.innerHeight - height));

  applyLayout(
    leftPx / Math.max(window.innerWidth, 1),
    topPx / Math.max(window.innerHeight, 1)
  );
});

window.addEventListener('mouseup', () => {
  if (!dragActive) {
    return;
  }
  dragActive = false;
  saveLayout();
});

window.addEventListener('keydown', (event) => {
  if (!editMode || event.key !== 'Escape') {
    return;
  }

  event.preventDefault();
  dragActive = false;
  saveLayout();

  fetch(`https://${resourceName}/hud:exitEdit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({
      x: layout.x,
      y: layout.y
    })
  }).catch(() => {});
});

window.addEventListener('resize', () => {
  if (layout.x == null || layout.y == null) {
    return;
  }
  applyLayout(layout.x, layout.y);
});
