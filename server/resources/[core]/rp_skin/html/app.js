const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const sexEl = document.getElementById('sex');
const saveBtn = document.getElementById('saveBtn');
const stateEl = document.getElementById('state');

const tabButtons = Array.from(document.querySelectorAll('.tab-btn[data-tab]'));
const tabPanels = Array.from(document.querySelectorAll('.tab-panel[data-panel]'));
const numericInputs = Array.from(document.querySelectorAll('input[type="number"][data-path]'));
const steppers = Array.from(document.querySelectorAll('.stepper[data-path]'));

const defaultSkin = {
  sex: 'm',
  components: {
    tshirt: 15,
    tshirtTexture: 0,
    arms: 15,
    armsTexture: 0,
    torso: 15,
    torsoTexture: 0,
    pants: 21,
    pantsTexture: 0,
    shoes: 34,
    shoesTexture: 0,
    hair: 0,
    hairTexture: 0,
    mask: 0,
    maskTexture: 0,
    chain: 0,
    chainTexture: 0
  },
  props: {
    hat: -1,
    hatTexture: 0,
    glasses: -1,
    glassesTexture: 0
  },
  overlays: {
    beard: -1,
    beardOpacity: 100,
    beardColor: 0,
    eyebrows: -1,
    eyebrowsOpacity: 100,
    eyebrowsColor: 0
  },
  features: {
    headBlendShapeFirst: 21,
    headBlendShapeSecond: 0,
    headBlendSkinFirst: 21,
    headBlendSkinSecond: 0,
    faceShape: 50,
    eyes: 0,
    eyeColor: 0,
    bodyShape: 50,
    eyebrows: -1,
    eyebrowsColor: 0
  }
};

const state = {
  mode: 'creator',
  activeTab: 'clothing',
  skin: JSON.parse(JSON.stringify(defaultSkin)),
  ranges: {
    components: {},
    props: {},
    overlays: {},
    features: {}
  }
};

let previewTimer = null;
let cancelInFlight = false;

const deepMerge = (base, incoming) => {
  const out = Array.isArray(base) ? [...base] : { ...base };
  Object.keys(incoming || {}).forEach((key) => {
    if (incoming[key] && typeof incoming[key] === 'object' && !Array.isArray(incoming[key])) {
      out[key] = deepMerge(out[key] || {}, incoming[key]);
    } else {
      out[key] = incoming[key];
    }
  });
  return out;
};

const post = async (name, data) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
  return response.json();
};

const getByPath = (root, path) => {
  const parts = String(path || '').split('.');
  let ref = root;
  for (let i = 0; i < parts.length; i += 1) {
    if (!ref || typeof ref !== 'object') {
      return undefined;
    }
    ref = ref[parts[i]];
  }
  return ref;
};

const setByPath = (root, path, value) => {
  const parts = String(path || '').split('.');
  let ref = root;
  for (let i = 0; i < parts.length - 1; i += 1) {
    if (!ref[parts[i]] || typeof ref[parts[i]] !== 'object') {
      ref[parts[i]] = {};
    }
    ref = ref[parts[i]];
  }
  ref[parts[parts.length - 1]] = value;
};

const getRangeForPath = (path) => {
  const range = getByPath(state.ranges, path);
  if (!range || typeof range !== 'object') {
    return { min: 0, max: 255 };
  }
  return {
    min: Number(range.min ?? 0),
    max: Number(range.max ?? 255)
  };
};

const clampToRange = (path, value) => {
  const range = getRangeForPath(path);
  let next = Number(value);
  if (!Number.isFinite(next)) {
    next = range.min;
  }
  next = Math.floor(next);
  if (next < range.min) next = range.min;
  if (next > range.max) next = range.max;
  return next;
};

const uiData = () => ({
  sex: state.skin.sex,
  components: state.skin.components,
  props: state.skin.props,
  overlays: state.skin.overlays,
  features: state.skin.features
});

const renderTabs = () => {
  tabButtons.forEach((button) => {
    const tab = button.dataset.tab;
    button.classList.toggle('active', tab === state.activeTab);
  });

  tabPanels.forEach((panel) => {
    const tab = panel.dataset.panel;
    panel.classList.toggle('active', tab === state.activeTab);
  });
};

const renderFields = () => {
  sexEl.value = state.skin.sex === 'f' ? 'f' : 'm';

  numericInputs.forEach((input) => {
    const path = input.dataset.path;
    const range = getRangeForPath(path);
    input.min = String(range.min);
    input.max = String(range.max);
    input.value = String(clampToRange(path, getByPath(state.skin, path)));
  });
};

const schedulePreview = () => {
  clearTimeout(previewTimer);
  previewTimer = setTimeout(async () => {
    try {
      const result = await post('previewSkin', uiData());
      if (result && result.ok) {
        if (result.skin && typeof result.skin === 'object') {
          state.skin = deepMerge(state.skin, result.skin);
        }
        if (result.ranges && typeof result.ranges === 'object') {
          state.ranges = deepMerge(state.ranges, result.ranges);
        }
        renderFields();
      }
    } catch (_err) {
      stateEl.textContent = 'Preview fehlgeschlagen.';
    }
  }, 60);
};

const setNumericField = (path, value, shouldPreview) => {
  const next = clampToRange(path, value);
  setByPath(state.skin, path, next);
  renderFields();
  if (shouldPreview) {
    schedulePreview();
  }
};

sexEl.addEventListener('change', () => {
  state.skin.sex = sexEl.value === 'f' ? 'f' : 'm';
  schedulePreview();
});

tabButtons.forEach((button) => {
  button.addEventListener('click', () => {
    state.activeTab = button.dataset.tab === 'features' ? 'features' : 'clothing';
    renderTabs();
  });
});

numericInputs.forEach((input) => {
  input.addEventListener('change', () => {
    setNumericField(input.dataset.path, input.value, true);
  });

  input.addEventListener('input', () => {
    setNumericField(input.dataset.path, input.value, false);
  });
});

steppers.forEach((stepper) => {
  stepper.addEventListener('click', (event) => {
    const button = event.target.closest('button.arrow');
    if (!button) {
      return;
    }

    event.preventDefault();
    const path = stepper.dataset.path;
    const delta = Number(button.dataset.dir || 0);
    const current = Number(getByPath(state.skin, path) || 0);
    setNumericField(path, current + delta, true);
  });
});

saveBtn.addEventListener('click', async () => {
  stateEl.textContent = 'Speichere Skin ...';
  try {
    const result = await post('saveSkin', uiData());
    stateEl.textContent = result && result.ok ? 'Gespeichert.' : (result?.message || 'Fehler beim Speichern.');
  } catch (_err) {
    stateEl.textContent = 'NUI-Fehler beim Speichern.';
  }
});

const cancelSkin = async () => {
  if (cancelInFlight || app.classList.contains('hidden')) {
    return;
  }

  cancelInFlight = true;
  try {
    await post('cancelSkin', {});
  } catch (_err) {
    // ignore cancel transport errors
  } finally {
    cancelInFlight = false;
  }
};

const rotateView = async (direction) => {
  try {
    await post('rotateView', { direction });
  } catch (_err) {
    // ignore rotate transport errors
  }
};

const zoomView = async (direction) => {
  try {
    await post('zoomView', { direction });
  } catch (_err) {
    // ignore zoom transport errors
  }
};

window.addEventListener('keydown', (event) => {
  if (app.classList.contains('hidden')) {
    return;
  }

  const key = event.key;
  if (key === 'ArrowLeft' || key === 'ArrowRight' || key === 'ArrowUp' || key === 'ArrowDown') {
    const active = document.activeElement;
    const isTextField = active && (
      active.tagName === 'INPUT' ||
      active.tagName === 'SELECT' ||
      active.tagName === 'TEXTAREA'
    );

    if (!isTextField) {
      event.preventDefault();
      if (key === 'ArrowLeft' || key === 'ArrowRight') {
        rotateView(key === 'ArrowLeft' ? -1 : 1);
      } else {
        zoomView(key === 'ArrowUp' ? -1 : 1);
      }
      return;
    }
  }

  if (event.key === 'Escape') {
    event.preventDefault();
    cancelSkin();
  }
});

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};

  if (action === 'open') {
    app.classList.remove('hidden');

    state.mode = String(data?.mode || 'creator');
    state.activeTab = 'clothing';
    titleEl.textContent = data?.title || 'Character Creator';
    subtitleEl.textContent = data?.subtitle || 'Grundauswahl für deinen Startlook.';

    state.skin = deepMerge(defaultSkin, data?.skin || {});
    state.skin.sex = state.skin.sex === 'f' ? 'f' : 'm';

    state.ranges = {
      components: {},
      props: {},
      overlays: {},
      features: {}
    };

    if (data?.ranges && typeof data.ranges === 'object') {
      state.ranges = deepMerge(state.ranges, data.ranges);
    }

    stateEl.textContent = '';
    renderTabs();
    renderFields();
  }

  if (action === 'close') {
    app.classList.add('hidden');
    stateEl.textContent = '';
    cancelInFlight = false;
  }
});
