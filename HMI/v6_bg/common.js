// HMI v4 背景圖產生器（800×480）。每頁 HTML 定義 ITEMS 後呼叫 render()。
// 色票：HMI/roundtable/rt_3_fable_final_plan.md B.1
const C = {
  BG: '#CFCDEA', TB: '#B9B6E0', TL: '#8E8AC4', FR: '#333333', TT: '#1D2F8F',
  PN: '#BFE6F3', PN2: '#D6EFFA', PB: '#7FB4C8', TX: '#222222', WH: '#FFFFFF',
  IB: '#888888', CR: '#FFFBE0', BL: '#1E3FD0', G1: '#2E7D32', G2: '#4CAF50',
  G3: '#55FF55', RL: '#FF5555', GY: '#9E9E9E', GD: '#606060', R1: '#C62828',
  R2: '#E8455F', AM: '#F9A825', BR: '#5A3B2E', SL: '#455A64', YL: '#FFD54F',
  BN: '#FFE9A8', BNB: '#C9A227', SB: '#222222', LB: '#555555',
};

// 每個項目：[x, y, w, h, 種類, 文字, 選項]
// 種類：rect 面板/色塊、text 文字、btn 按鈕（框 SB）、lamp 燈號（框 LB）、wbox 白框、bbox 藍框、line 線
function render(items) {
  const demo = location.search.includes('demo');
  if (demo) document.body.classList.add('demo');
  for (const it of items) {
    const [x, y, w, h, kind, text, o = {}] = it;
    if (o.demo && !demo) continue;
    const d = document.createElement('div');
    d.className = 'a ' + kind;
    Object.assign(d.style, { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
    if (o.bg) d.style.background = C[o.bg] || o.bg;
    if (o.fg) d.style.color = C[o.fg] || o.fg;
    if (o.bd) d.style.borderColor = C[o.bd] || o.bd;
    if (o.fs) d.style.fontSize = o.fs + 'px';
    if (o.al) d.style.justifyContent = o.al === 'l' ? 'flex-start' : o.al === 'r' ? 'flex-end' : 'center';
    if (o.mono) d.style.fontFamily = 'Consolas, "Cascadia Mono", monospace';
    if (o.pad) d.style.padding = o.pad;
    if (o.lh) d.style.lineHeight = o.lh;
    if (o.css) d.style.cssText += o.css;
    if (text) d.innerHTML = '<div>' + text + '</div>';  // 包一層，避免 flex 吃掉 <br>
    document.getElementById('scr').appendChild(d);
  }
  // 殼層：標題列、底線、外框
  const top = document.createElement('div');
  top.className = 'a frame';
  document.getElementById('scr').appendChild(top);
}
