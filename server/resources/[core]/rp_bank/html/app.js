const app = document.getElementById('app');
const closeBtn = document.getElementById('closeBtn');
const cashEl = document.getElementById('cash');
const bankEl = document.getElementById('bank');
const accountNumberEl = document.getElementById('accountNumber');
const txEl = document.getElementById('transactions');
const stateEl = document.getElementById('state');

const depositAmount = document.getElementById('depositAmount');
const withdrawAmount = document.getElementById('withdrawAmount');
const transferMode = document.getElementById('transferMode');
const transferTarget = document.getElementById('transferTarget');
const transferAmount = document.getElementById('transferAmount');

const post = async (name, body = {}) => {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  });

  return response.json();
};

const fmtMoney = (value) => `${Number(value || 0).toLocaleString('de-DE')}$`;

const renderTransactions = (items = []) => {
  txEl.innerHTML = '';
  if (!items.length) {
    txEl.innerHTML = '<div class="tx"><span>Keine Transaktionen vorhanden.</span></div>';
    return;
  }

  items.forEach((item) => {
    const row = document.createElement('div');
    row.className = 'tx';
    row.innerHTML = `
      <div>
        <div>${item.transaction_type || 'system'} - ${fmtMoney(item.amount)}</div>
        <div class="meta">${item.reference || 'ohne Referenz'}</div>
      </div>
      <div class="meta">${new Date(item.created_at).toLocaleString('de-DE')}</div>
    `;
    txEl.appendChild(row);
  });
};

const render = (data = {}) => {
  accountNumberEl.textContent = data.accountNumber || '-';
  cashEl.textContent = fmtMoney(data.cash);
  bankEl.textContent = fmtMoney(data.bank);
  renderTransactions(data.transactions || []);
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'open') {
    app.classList.remove('hidden');
    render(data);
  }
  if (action === 'update') {
    render(data);
  }
  if (action === 'close') {
    app.classList.add('hidden');
    stateEl.textContent = '';
  }
});

closeBtn.addEventListener('click', async () => {
  await post('bank:close');
});

document.getElementById('depositBtn').addEventListener('click', async () => {
  await post('bank:deposit', { amount: Number(depositAmount.value || 0) });
  stateEl.textContent = 'Einzahlung gesendet.';
});

document.getElementById('withdrawBtn').addEventListener('click', async () => {
  await post('bank:withdraw', { amount: Number(withdrawAmount.value || 0) });
  stateEl.textContent = 'Auszahlung gesendet.';
});

document.getElementById('transferBtn').addEventListener('click', async () => {
  await post('bank:transfer', {
    mode: transferMode.value,
    target: transferTarget.value,
    amount: Number(transferAmount.value || 0)
  });
  stateEl.textContent = 'Überweisung gesendet.';
});
