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

const pad2 = (value) => String(value).padStart(2, '0');

const toInputDate = (value) => {
  const text = String(value || '').trim();
  if (!text) return '';

  // Accept direct HTML date format.
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    return text;
  }

  // Accept DB datetime / ISO datetime and cut to date part.
  const isoLike = text.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T].*)?$/);
  if (isoLike) {
    return `${isoLike[1]}-${isoLike[2]}-${isoLike[3]}`;
  }

  // Accept dd.mm.yyyy
  const dotFormat = text.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
  if (dotFormat) {
    const day = Number(dotFormat[1]);
    const month = Number(dotFormat[2]);
    if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
      return `${dotFormat[3]}-${pad2(month)}-${pad2(day)}`;
    }
  }

  // Accept mm/dd/yyyy or dd/mm/yyyy (heuristic).
  const slashFormat = text.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (slashFormat) {
    let first = Number(slashFormat[1]);
    let second = Number(slashFormat[2]);
    const year = slashFormat[3];

    let month = first;
    let day = second;
    if (first > 12 && second <= 12) {
      month = second;
      day = first;
    }

    if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
      return `${year}-${pad2(month)}-${pad2(day)}`;
    }
  }

  const parsedDate = new Date(text);
  if (!Number.isNaN(parsedDate.getTime())) {
    const year = parsedDate.getFullYear();
    const month = parsedDate.getMonth() + 1;
    const day = parsedDate.getDate();
    if (year >= 1900 && year <= 2999) {
      return `${year}-${pad2(month)}-${pad2(day)}`;
    }
  }

  return '';
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
