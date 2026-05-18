const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const listEl = document.getElementById('list');
const closeBtn = document.getElementById('closeBtn');
const storeBtn = document.getElementById('storeBtn');

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });
  return response.json();
};

const render = (data) => {
  titleEl.textContent = data.garageLabel || 'Garage';
  listEl.innerHTML = '';

  (data.vehicles || []).forEach((vehicle) => {
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = `
      <strong>${vehicle.label} (${vehicle.plate})</strong>
      <p>Status: ${Number(vehicle.stored) === 1 ? 'Eingeparkt' : 'Ausgeparkt'}</p>
      <p>Zustand: Motor ${Math.round(vehicle.engine_health || 1000)} | Karosserie ${Math.round(vehicle.body_health || 1000)}</p>
      <button ${Number(vehicle.stored) !== 1 ? 'disabled' : ''}>Ausparken</button>
    `;

    row.querySelector('button').addEventListener('click', async () => {
      await post('garage:spawnVehicle', { vehicleId: vehicle.id });
    });

    listEl.appendChild(row);
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
  await post('garage:close');
});

storeBtn.addEventListener('click', async () => {
  await post('garage:storeVehicle');
});
