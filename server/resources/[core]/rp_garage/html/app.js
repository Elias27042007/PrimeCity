const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const listEl = document.getElementById('list');
const closeBtn = document.getElementById('closeBtn');
const storeBtn = document.getElementById('storeBtn');
const searchInput = document.getElementById('searchInput');

const state = {
  garageLabel: 'Garage',
  vehicles: [],
  query: ''
};

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });
  return response.json();
};

const render = () => {
  titleEl.textContent = state.garageLabel || 'Garage';
  listEl.innerHTML = '';

  const query = state.query.trim().toLowerCase();
  const filtered = (state.vehicles || []).filter((vehicle) => {
    if (!query) return true;
    const label = String(vehicle.label || '').toLowerCase();
    const plate = String(vehicle.plate || '').toLowerCase();
    return label.includes(query) || plate.includes(query);
  });

  if (filtered.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = 'Keine Fahrzeuge gefunden.';
    listEl.appendChild(empty);
    return;
  }

  filtered.forEach((vehicle) => {
    const isStored = Number(vehicle.stored) === 1;
    const actionLabel = isStored ? 'Ausparken' : 'Einparken';
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = `
      <strong>${vehicle.label} (${vehicle.plate})</strong>
      <p>Status: ${isStored ? 'Eingeparkt' : 'Ausgeparkt'}</p>
      <p>Zustand: Motor ${Math.round(vehicle.engine_health || 1000)} | Karosserie ${Math.round(vehicle.body_health || 1000)}</p>
      <button>${actionLabel}</button>
    `;

    row.querySelector('button').addEventListener('click', async () => {
      if (isStored) {
        await post('garage:spawnVehicle', { vehicleId: vehicle.id });
      } else {
        await post('garage:storeVehicle', {
          mode: 'single',
          vehicleId: vehicle.id,
          plate: vehicle.plate
        });
      }
    });

    listEl.appendChild(row);
  });
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    app.classList.remove('hidden');
    state.garageLabel = data?.garageLabel || 'Garage';
    state.vehicles = Array.isArray(data?.vehicles) ? data.vehicles : [];
    state.query = '';
    searchInput.value = '';
    render();
  }
  if (action === 'close') {
    app.classList.add('hidden');
  }
});

closeBtn.addEventListener('click', async () => {
  await post('garage:close');
});

storeBtn.addEventListener('click', async () => {
  await post('garage:storeVehicle', { mode: 'all' });
});

searchInput.addEventListener('input', () => {
  state.query = String(searchInput.value || '');
  render();
});
