const root = document.getElementById('mod');
root.innerHTML = `
<div id="hk-top">
  <div class="hk-team hk-a"><span class="hk-name">DAWN</span><span id="hk-sa" class="hk-score">0</span></div>
  <div id="hk-time">0:00</div>
  <div class="hk-team hk-b"><span id="hk-sb" class="hk-score">0</span><span class="hk-name">DUSK</span></div>
</div>
<div id="hk-boss"><div id="hk-boss-label">THE TYRANT</div><div id="hk-boss-bar"><div id="hk-boss-fill"></div></div></div>
<div id="hk-me"><img src="../../img/crown.png"><div><div id="hk-lv">Lv 1</div><div id="hk-gold"><img src="../../img/coin.png"> <span id="hk-gv">500</span></div></div></div>
<div id="hk-feed"></div>`;
const $ = (id) => document.getElementById(id);
window.addEventListener('sigfmod', (e) => {
  const d = e.detail;
  if (d.a !== undefined) $('hk-sa').textContent = d.a;
  if (d.b !== undefined) $('hk-sb').textContent = d.b;
  if (d.time !== undefined) $('hk-time').textContent = Math.floor(d.time / 60) + ':' + String(d.time % 60).padStart(2, '0');
  if (d.gold !== undefined) $('hk-gv').textContent = d.gold;
  if (d.level !== undefined) $('hk-lv').textContent = 'Lv ' + d.level;
  if (d.boss !== undefined) {
    $('hk-boss').style.display = d.boss >= 0 ? 'block' : 'none';
    $('hk-boss-fill').style.width = Math.max(0, d.boss * 100) + '%';
  }
  if (d.feed) {
    const row = document.createElement('div');
    row.className = 'hk-row';
    row.style.borderLeftColor = d.feedColor || '#ffd34d';
    row.textContent = d.feed;
    $('hk-feed').appendChild(row);
    while ($('hk-feed').children.length > 5) $('hk-feed').removeChild($('hk-feed').firstChild);
    setTimeout(() => row.remove(), 6000);
  }
});
