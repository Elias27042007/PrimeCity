const root = document.getElementById('notify-root');

let audioCtx = null;

function playTicketSound() {
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }

    const now = audioCtx.currentTime;
    const toneA = audioCtx.createOscillator();
    const toneB = audioCtx.createOscillator();
    const gain = audioCtx.createGain();

    toneA.type = 'sine';
    toneA.frequency.setValueAtTime(740, now);
    toneB.type = 'sine';
    toneB.frequency.setValueAtTime(980, now + 0.11);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.09, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.27);

    toneA.connect(gain);
    toneB.connect(gain);
    gain.connect(audioCtx.destination);

    toneA.start(now);
    toneA.stop(now + 0.15);
    toneB.start(now + 0.11);
    toneB.stop(now + 0.27);
  } catch (err) {
    // Audio fallback intentionally silent.
  }
}

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action !== 'notify' || !data) return;

  const card = document.createElement('div');
  card.className = `toast ${data.type || 'info'}`;

  const title = document.createElement('div');
  title.className = 'title';
  title.textContent = data.title || 'Info';

  const msg = document.createElement('div');
  msg.className = 'message';
  msg.textContent = data.message || '';

  card.appendChild(title);
  card.appendChild(msg);
  root.prepend(card);

  const duration = Number(data.duration) || 4500;
  setTimeout(() => {
    card.style.opacity = '0';
    card.style.transform = 'translateX(25px)';
    card.style.transition = 'all .2s ease';
    setTimeout(() => card.remove(), 220);
  }, duration);

  while (root.children.length > 4) {
    root.lastChild.remove();
  }

  if (data.sound === 'ticket' || data.playSound === true) {
    playTicketSound();
  }
});

fetch(`https://${GetParentResourceName()}/ready`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  body: JSON.stringify({ ok: true })
}).catch(() => {});
