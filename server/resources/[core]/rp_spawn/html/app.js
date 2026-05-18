const loader = document.getElementById('loader');
const label = document.getElementById('label');

window.addEventListener('message', (event) => {
  const { action } = event.data || {};
  if (action === 'show') {
    loader.classList.remove('hidden');
    label.textContent = event.data.label || 'Lade Daten ...';
  }
  if (action === 'hide') {
    loader.classList.add('hidden');
  }
});
