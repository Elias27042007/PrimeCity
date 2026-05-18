const app = document.getElementById('app');
const form = document.getElementById('identityForm');
const message = document.getElementById('message');

const setVisible = (visible) => {
  app.classList.toggle('hidden', !visible);
  if (!visible) {
    form.reset();
    message.textContent = '';
  }
};

window.addEventListener('message', (event) => {
  const { action } = event.data || {};
  if (action === 'open') setVisible(true);
  if (action === 'close') setVisible(false);
});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  message.textContent = '';

  const data = Object.fromEntries(new FormData(form).entries());
  data.height = Number(data.height || 0);

  try {
    const response = await fetch(`https://${GetParentResourceName()}/submitIdentity`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    });

    const result = await response.json();
    if (!result.ok) {
      message.textContent = result.message || 'Validierung fehlgeschlagen.';
    }
  } catch (err) {
    message.textContent = 'NUI-Fehler beim Senden.';
  }
});
