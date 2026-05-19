const app = document.getElementById('app');
const form = document.getElementById('identityForm');
const message = document.getElementById('message');
const title = document.getElementById('title');
const subtitle = document.getElementById('subtitle');
const submitButton = document.getElementById('submitButton');
let currentMode = 'create';
let cancelInFlight = false;

const setVisible = (visible) => {
  app.classList.toggle('hidden', !visible);
  if (!visible) {
    cancelInFlight = false;
    currentMode = 'create';
    title.textContent = 'Personalausweis erstellen';
    subtitle.textContent = 'Bitte gib deine Charakterdaten ein.';
    submitButton.textContent = 'Charakter erstellen';
    form.reset();
    message.textContent = '';
  }
};

const toInputDate = (value) => {
  const text = String(value || '').trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : '';
};

const applyIdentityData = (identity) => {
  if (!identity || typeof identity !== 'object') return;

  if (typeof identity.firstName === 'string') form.elements.firstName.value = identity.firstName;
  if (typeof identity.lastName === 'string') form.elements.lastName.value = identity.lastName;
  form.elements.dateOfBirth.value = toInputDate(identity.dateOfBirth);
  if (typeof identity.sex === 'string') form.elements.sex.value = identity.sex;
  if (typeof identity.height !== 'undefined') form.elements.height.value = Number(identity.height || 0) || 175;
  if (typeof identity.nationality === 'string') form.elements.nationality.value = identity.nationality;
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    setVisible(true);
    currentMode = data?.mode === 'update' ? 'update' : 'create';
    if (data?.mode === 'admin_create') {
      currentMode = 'admin_create';
    }

    if (currentMode === 'update') {
      title.textContent = 'Personalausweis ändern';
      subtitle.textContent = 'Passe Name und Geburtsdaten deines Charakters an.';
      submitButton.textContent = 'Änderungen speichern';
      applyIdentityData(data?.identity);
    } else {
      title.textContent = 'Personalausweis erstellen';
      subtitle.textContent = 'Bitte gib deine Charakterdaten ein.';
      submitButton.textContent = 'Charakter erstellen';
    }
  }
  if (action === 'close') setVisible(false);
});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  message.textContent = '';

  const data = Object.fromEntries(new FormData(form).entries());
  data.height = Number(data.height || 0);
  data.mode = currentMode;

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

const cancelIdentity = async () => {
  if (cancelInFlight || app.classList.contains('hidden')) {
    return;
  }

  cancelInFlight = true;
  try {
    await fetch(`https://${GetParentResourceName()}/cancelIdentity`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({})
    });
  } catch (_err) {
    // ignore cancel transport errors
  } finally {
    cancelInFlight = false;
  }
};

window.addEventListener('keydown', (event) => {
  if (app.classList.contains('hidden')) {
    return;
  }

  if (event.key === 'Escape') {
    event.preventDefault();
    cancelIdentity();
  }
});
