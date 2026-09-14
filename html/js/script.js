const app = document.getElementById('app');
const statusDot = document.getElementById('statusDot');
const statusTag = document.getElementById('statusTag');
const charSub = document.getElementById('charSub');
const charName = document.getElementById('charName');
const charKills = document.getElementById('charKills');
const charDeaths = document.getElementById('charDeaths');
const startBtn = document.getElementById('startBtn');
const startBtnText = document.getElementById('startBtnText');
const nodeTag = document.getElementById('nodeTag');
const clockTag = document.getElementById('clockTag');

function resourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'Nabd-multicharacter';
}

function randHex(len) {
    let out = '';
    const chars = '0123456789ABCDEF';
    for (let i = 0; i < len; i++) out += chars[Math.floor(Math.random() * chars.length)];
    return out;
}

nodeTag.textContent = `NODE :: ${randHex(3)}-${randHex(3)}`;

function tickClock() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    clockTag.textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
}
setInterval(tickClock, 1000);
tickClock();

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            app.classList.remove('hidden');
            requestAnimationFrame(() => app.classList.add('visible'));
            statusDot.classList.remove('is-ready');
            statusTag.textContent = 'INITIALIZING...';
            charSub.textContent = 'SCANNING RECORDS';
            charName.textContent = '— — —';
            charKills.textContent = '0';
            charDeaths.textContent = '0';
            startBtn.disabled = true;
            startBtnText.textContent = 'Start';
            break;

        case 'setCharacter': {
            const info = data.charinfo || {};
            const stats = data.stats || {};
            const fullName = `${info.firstname || ''} ${info.lastname || ''}`.trim() || 'UNKNOWN';

            charName.textContent = fullName;
            charKills.textContent = stats.kills ?? 0;
            charDeaths.textContent = stats.deaths ?? 0;

            if (data.isNew) {
                statusTag.textContent = 'NEW IDENTITY CREATED';
                charSub.textContent = 'AUTO-GENERATED FROM DISCORD';
            } else {
                statusTag.textContent = 'IDENTITY VERIFIED';
                charSub.textContent = 'WELCOME BACK';
            }

            statusDot.classList.add('is-ready');
            startBtn.disabled = false;
            break;
        }

        case 'close':
            app.classList.remove('visible');
            setTimeout(() => app.classList.add('hidden'), 300);
            break;
    }
});

startBtn.addEventListener('click', () => {
    if (startBtn.disabled) return;
    startBtn.disabled = true;
    startBtnText.textContent = 'جاري الدخول...';
    statusTag.textContent = 'ESTABLISHING SESSION...';

    fetch(`https://${resourceName()}/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({}),
    }).catch(() => {});
});
