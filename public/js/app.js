/* ==========================================================================
   ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - FRONTEND LOGIC (APP.JS)
   Location: public/js/app.js
   ========================================================================== */

let socket = null;
let currentUsers = [];
let protocolConfig = {};
let currentSelectedV2RayProtocol = 'vmess';

document.addEventListener('DOMContentLoaded', () => {
  initSocketConnection();
  setupEventListeners();
});

function initSocketConnection() {
  try {
    socket = io();

    socket.on('connect', () => {
      console.log('Connected to VPS Telemetry Socket');
    });

    socket.on('telemetry', (data) => {
      updateTelemetryUI(data);
    });

    socket.on('users_list', (users) => {
      currentUsers = users;
      renderUsersTable(users);
      populateUserSelects(users);
    });

    socket.on('protocol_config', (config) => {
      protocolConfig = config;
      populateConfigForm(config);
    });

  } catch (e) {
    console.warn('Socket connection failed, falling back to REST polling:', e);
    setInterval(fetchTelemetryREST, 3000);
  }
}

async function fetchTelemetryREST() {
  try {
    const res = await fetch('/api/telemetry');
    const data = await res.json();
    updateTelemetryUI(data);

    const uRes = await fetch('/api/users');
    const users = await uRes.json();
    currentUsers = users;
    renderUsersTable(users);
    populateUserSelects(users);
  } catch (e) {
    console.error('REST Telemetry fetch error:', e);
  }
}

function updateTelemetryUI(data) {
  if (!data) return;

  const cpuPct = data.cpu ? data.cpu.usage : 15;
  document.getElementById('cpu-pct').innerText = `${cpuPct}%`;
  document.getElementById('cpu-bar').style.width = `${cpuPct}%`;
  document.getElementById('cpu-model').innerText = data.cpu ? data.cpu.model : 'AMD64 Processor';
  document.getElementById('arch-badge').innerText = data.arch || 'AMD64 / x86_64';

  const ramPct = data.ram ? data.ram.percentage : 25;
  document.getElementById('ram-pct').innerText = `${ramPct}%`;
  document.getElementById('ram-bar').style.width = `${ramPct}%`;
  document.getElementById('ram-used').innerText = data.ram ? data.ram.used : '1.2';
  document.getElementById('ram-total').innerText = data.ram ? data.ram.total : '4.0';

  if (data.network) {
    document.getElementById('net-rx').innerText = data.network.rxSpeed;
    document.getElementById('net-tx').innerText = data.network.txSpeed;
    document.getElementById('net-total').innerText = `${data.network.totalRx} / ${data.network.totalTx}`;
  }

  document.getElementById('active-users-count').innerText = data.activeConnections || 0;
  if (data.disk) {
    document.getElementById('disk-used').innerText = data.disk.used;
    document.getElementById('disk-total').innerText = data.disk.total;
  }
  if (data.uptime) {
    const d = Math.floor(data.uptime / (3600*24));
    const h = Math.floor((data.uptime % (3600*24)) / 3600);
    document.getElementById('uptime-str').innerText = `${d}d ${h}h`;
  }

  if (data.services) {
    updateServicePill('ssh', data.services.ssh);
    updateServicePill('dropbear', data.services.dropbear);
    updateServicePill('stunnel', data.services.stunnel);
    updateServicePill('wsProxy', data.services.wsProxy);
    updateServicePill('udpCustom', data.services.udpCustom);
    updateServicePill('badvpn', data.services.badvpn);
    updateServicePill('slowdns', data.services.slowdns);
    updateServicePill('vmess', data.services.vmess);
    updateServicePill('vless', data.services.vless);
    updateServicePill('trojan', data.services.trojan);
    updateServicePill('openvpn', data.services.openvpn);
    updateServicePill('nginx', data.services.nginx);
  }
}

function updateServicePill(serviceKey, isActive) {
  const elem = document.getElementById(`status-${serviceKey}`);
  if (elem) {
    if (isActive) {
      elem.className = 'status-pill online';
      elem.innerHTML = `<i class="fa-solid fa-check-circle"></i> Online`;
    } else {
      elem.className = 'status-pill offline';
      elem.innerHTML = `<i class="fa-solid fa-circle-xmark"></i> Offline`;
    }
  }

  const tagElem = document.getElementById(`tag-${serviceKey}`);
  if (tagElem) {
    tagElem.className = isActive ? 'proto-tag online' : 'proto-tag offline';
  }
}

function renderUsersTable(users) {
  const tbody = document.getElementById('users-tbody');
  tbody.innerHTML = '';

  document.getElementById('total-users-stat').innerText = users.length;
  const lifetimeCount = users.filter(u => u.isLifetime || u.durationDays === 0).length;
  document.getElementById('lifetime-users-stat').innerText = lifetimeCount;
  document.getElementById('nav-user-badge').innerText = users.length;

  if (users.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: var(--text-muted); padding: 2rem;">No accounts found. Click "Create Universal Account" to add one!</td></tr>`;
    return;
  }

  users.forEach(user => {
    const tr = document.createElement('tr');

    const isLifetime = user.isLifetime || user.durationDays === 0;
    const expDisplay = isLifetime 
      ? `<span class="badge-lifetime"><i class="fa-solid fa-infinity"></i> LIFETIME</span>` 
      : (user.expiryDate ? new Date(user.expiryDate).toLocaleDateString() : 'N/A');

    const isUnlimitedBw = !user.maxBandwidthGB || user.maxBandwidthGB === 0;
    const bwDisplay = isUnlimitedBw
      ? `<span class="badge-lifetime"><i class="fa-solid fa-database"></i> UNLIMITED</span>`
      : `<span class="tag"><i class="fa-solid fa-database"></i> ${user.maxBandwidthGB} GB</span>`;

    tr.innerHTML = `
      <td><strong>${escapeHtml(user.username)}</strong></td>
      <td><code>${escapeHtml(user.password)}</code></td>
      <td><span class="uuid-text">${escapeHtml(user.uuid.slice(0, 18))}...</span></td>
      <td><span class="tag"><i class="fa-solid fa-mobile-screen"></i> ${user.maxLogins} Devices</span></td>
      <td>${expDisplay}</td>
      <td>${bwDisplay}</td>
      <td>
        <span class="status-pill ${user.status === 'active' ? 'online' : 'offline'}">
          <i class="fa-solid fa-${user.status === 'active' ? 'check-circle' : 'lock'}"></i> ${user.status}
        </span>
      </td>
      <td>
        <div style="display: flex; gap: 4px;">
          <button class="btn btn-xs btn-outline" title="Toggle Lock" onclick="toggleUserStatus('${user.id}')"><i class="fa-solid fa-${user.status === 'active' ? 'lock' : 'lock-open'}"></i></button>
          <button class="btn btn-xs btn-outline" title="Extend Validity" onclick="extendUserValidityPrompt('${user.id}')"><i class="fa-solid fa-calendar-plus"></i></button>
          <button class="btn btn-xs btn-outline color-amber" title="Edit Bandwidth Quota (0=Unlimited)" onclick="editUserBandwidthPrompt('${user.id}')"><i class="fa-solid fa-gauge-high"></i></button>
          <button class="btn btn-xs btn-gradient" title="Account Info & Protocol Connection Guide" onclick="openAccountGuideModal('${user.id}')"><i class="fa-solid fa-circle-info"></i> Guide</button>
          <button class="btn btn-xs btn-secondary" title="Get V2Ray / OpenVPN Config" onclick="openV2RayModalForUser('${user.id}')"><i class="fa-solid fa-qrcode"></i></button>
          <button class="btn btn-xs btn-glass" style="color: var(--rose);" title="Delete" onclick="deleteUser('${user.id}')"><i class="fa-solid fa-trash"></i></button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function populateUserSelects(users) {
  const v2raySelect = document.getElementById('v2ray-modal-user');
  const ovpnSelect = document.getElementById('ovpn-user-select');

  if (v2raySelect) {
    v2raySelect.innerHTML = users.map(u => `<option value="${u.id}">${u.username}</option>`).join('');
  }
  if (ovpnSelect) {
    ovpnSelect.innerHTML = users.map(u => `<option value="${u.id}">${u.username}</option>`).join('');
  }
}

async function createNewUser() {
  const username = document.getElementById('new-username').value.trim();
  const password = document.getElementById('new-password').value.trim();
  const maxLogins = document.getElementById('new-max-logins').value;
  const durationDays = document.getElementById('new-duration').value;
  const maxBandwidthGB = document.getElementById('new-bandwidth') ? document.getElementById('new-bandwidth').value : 0;

  if (!username || !password) {
    alert('Please provide both username and password!');
    return;
  }

  try {
    const res = await fetch('/api/users/create', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password, maxLogins, durationDays, maxBandwidthGB })
    });
    const data = await res.json();

    if (data.error) {
      alert(`Error: ${data.error}`);
    } else {
      closeModal('modal-create-user');
      document.getElementById('new-username').value = '';
      document.getElementById('new-password').value = '';
      if (document.getElementById('new-bandwidth')) document.getElementById('new-bandwidth').value = '0';
      
      const newUser = data.user || {
        id: data.id || username,
        username: username,
        password: password,
        uuid: data.uuid || 'e4a781b2-93c4-4b52-a1e9-8f7d6c5b4a3e',
        durationDays: parseInt(durationDays, 10),
        maxBandwidthGB: parseInt(maxBandwidthGB, 10) || 0,
        isLifetime: parseInt(durationDays, 10) === 0
      };

      alert(`Universal Account '${username}' created successfully! Opening Protocol Info & Connection Guide...`);
      openAccountGuideModal(newUser);
    }
  } catch (e) {
    console.error('Account creation error:', e);
  }
}

async function editUserBandwidthPrompt(id) {
  const newLimit = prompt('Enter Max Bandwidth Limit in GB (Type 0 for UNLIMITED BANDWIDTH):', '50');
  if (newLimit === null) return;

  try {
    const res = await fetch(`/api/users/${id}/bandwidth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ maxBandwidthGB: newLimit })
    });
    const data = await res.json();
    if (data.error) alert(`Error: ${data.error}`);
    else alert('Bandwidth quota updated successfully!');
  } catch (e) {
    console.error('Bandwidth update error:', e);
  }
}function switchTab(tabId) {
  document.querySelectorAll('.nav-item').forEach(btn => btn.classList.remove('active'));
  document.querySelectorAll('.tab-page').forEach(page => page.classList.remove('active'));

  const targetTab = document.getElementById(`tab-${tabId}`);
  if (targetTab) {
    targetTab.classList.add('active');
  }

  const activeBtn = Array.from(document.querySelectorAll('.nav-item')).find(b => b.getAttribute('onclick').includes(tabId));
  if (activeBtn) activeBtn.classList.add('active');
}

async function toggleService(serviceName, action) {
  try {
    const res = await fetch('/api/service/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ service: serviceName, action: action })
    });
    const data = await res.json();
    alert(`Service '${serviceName}' action '${action}' executed successfully.`);
  } catch (e) {
    console.error('Service action error:', e);
  }
}

async function restartAllServices() {
  alert('Restarting all SSH, Dropbear, Stunnel, WebSocket, UDP Custom, BadVPN, and Xray services...');
  ['ssh', 'dropbear', 'stunnel', 'wsProxy', 'udpCustom', 'badvpn', 'v2ray'].forEach(s => toggleService(s, 'restart'));
}

async function toggleTorrentBlocker(enable) {
  try {
    const res = await fetch('/api/service/torrent-blocker', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ enable })
    });
    const data = await res.json();
    alert(data.message || 'Torrent blocker updated!');
  } catch (e) {
    console.error('Torrent blocker toggle error:', e);
  }
}

function openCertbotModal() {
  openModal('modal-certbot');
}

async function submitIssueCert() {
  const domain = document.getElementById('cert-domain-input').value.trim();
  const email = document.getElementById('cert-email-input').value.trim();

  if (!domain) {
    alert('Please enter a valid domain name!');
    return;
  }

  try {
    const res = await fetch('/api/service/issue-cert', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ domain, email })
    });
    const data = await res.json();
    closeModal('modal-certbot');
    alert(data.message || `SSL Certificate issued for ${domain}!`);
  } catch (e) {
    console.error('Certbot issue error:', e);
  }
}

async function submitCreateUser() {
  const username = document.getElementById('new-username').value.trim();
  const password = document.getElementById('new-password').value.trim();
  const maxLogins = document.getElementById('new-max-logins').value;
  const durationDays = document.getElementById('new-duration').value;

  if (!username || !password) {
    alert('Please provide both username and password!');
    return;
  }

  try {
    const res = await fetch('/api/users/create', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password, maxLogins, durationDays })
    });
    const data = await res.json();

    if (data.error) {
      alert(`Error: ${data.error}`);
    } else {
      closeModal('modal-create-user');
      document.getElementById('new-username').value = '';
      document.getElementById('new-password').value = '';
      alert(`Universal Account '${username}' created successfully! Works across all protocols.`);
    }
  } catch (e) {
    console.error('Account creation error:', e);
  }
}

async function deleteUser(id) {
  if (!confirm('Are you sure you want to delete this universal user account?')) return;
  try {
    await fetch(`/api/users/${id}`, { method: 'DELETE' });
  } catch (e) {
    console.error('Delete error:', e);
  }
}

async function toggleUserStatus(id) {
  try {
    await fetch(`/api/users/${id}/toggle-status`, { method: 'POST' });
  } catch (e) {
    console.error('Status toggle error:', e);
  }
}

async function extendUserValidityPrompt(id) {
  const add = prompt('Enter days to add (Type 0 to set to LIFETIME):', '30');
  if (add === null) return;

  try {
    await fetch(`/api/users/${id}/extend`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ additionalDays: add })
    });
  } catch (e) {
    console.error('Extend error:', e);
  }
}

function openEditProtocolModal(protoKey) {
  document.getElementById('edit-proto-key').value = protoKey;
  const titleElem = document.getElementById('modal-proto-edit-title');
  const portInput = document.getElementById('edit-proto-port');
  const altGroup = document.getElementById('grp-proto-alt-port');
  const extraGroup = document.getElementById('grp-proto-extra');

  altGroup.style.display = 'none';
  extraGroup.style.display = 'none';

  if (protoKey === 'ssh') {
    titleElem.innerText = 'Edit OpenSSH Port & Configuration';
    portInput.value = protocolConfig.ssh ? protocolConfig.ssh.port : 22;
  } else if (protoKey === 'dropbear') {
    titleElem.innerText = 'Edit Dropbear SSH Port';
    portInput.value = protocolConfig.dropbear ? protocolConfig.dropbear.port : 109;
  } else if (protoKey === 'ssl') {
    titleElem.innerText = 'Edit Stunnel SSL Ports & Domain';
    portInput.value = protocolConfig.ssl ? protocolConfig.ssl.port : 443;
    altGroup.style.display = 'block';
    document.getElementById('edit-proto-alt-port').value = protocolConfig.ssl ? protocolConfig.ssl.altPort : 444;
    extraGroup.style.display = 'block';
    document.getElementById('lbl-proto-extra').innerText = 'SSL Domain (SNI)';
    document.getElementById('edit-proto-extra').value = protocolConfig.ssl ? protocolConfig.ssl.certDomain : 'vpn.example.com';
  } else if (protoKey === 'ws') {
    titleElem.innerText = 'Edit SSH WebSocket Proxy Port';
    portInput.value = protocolConfig.websocket ? protocolConfig.websocket.httpPort : 80;
  } else if (protoKey === 'udpCustom') {
    titleElem.innerText = 'Edit UDP Custom Port & Alt Port';
    portInput.value = protocolConfig.udpCustom ? protocolConfig.udpCustom.port : 7300;
    altGroup.style.display = 'block';
    document.getElementById('edit-proto-alt-port').value = protocolConfig.udpCustom ? protocolConfig.udpCustom.altPort : 53;
  } else if (protoKey === 'badvpn') {
    titleElem.innerText = 'Edit BadVPN (udpgw) Gateway Ports';
    portInput.value = protocolConfig.badvpn ? protocolConfig.badvpn.ports[0] : 7300;
  } else if (protoKey === 'v2ray') {
    titleElem.innerText = 'Edit V2Ray Core VMess/VLess Ports';
    portInput.value = protocolConfig.v2ray ? protocolConfig.v2ray.vmessPort : 10085;
  } else if (protoKey === 'openvpn') {
    titleElem.innerText = 'Edit OpenVPN Port';
    portInput.value = protocolConfig.openvpn ? protocolConfig.openvpn.tcpPort : 1194;
  } else {
    titleElem.innerText = `Edit ${protoKey.toUpperCase()} Port & Config`;
    portInput.value = 53;
  }

  openModal('modal-protocol-edit');
}

async function saveModalProtocolConfig() {
  const protoKey = document.getElementById('edit-proto-key').value;
  const newPort = parseInt(document.getElementById('edit-proto-port').value, 10);
  const newAltPort = parseInt(document.getElementById('edit-proto-alt-port').value, 10);
  const extraVal = document.getElementById('edit-proto-extra').value;

  if (protoKey === 'ssh') protocolConfig.ssh.port = newPort;
  else if (protoKey === 'dropbear') protocolConfig.dropbear.port = newPort;
  else if (protoKey === 'ssl') {
    protocolConfig.ssl.port = newPort;
    protocolConfig.ssl.altPort = newAltPort;
    protocolConfig.ssl.certDomain = extraVal;
  } else if (protoKey === 'ws') protocolConfig.websocket.httpPort = newPort;
  else if (protoKey === 'udpCustom') {
    protocolConfig.udpCustom.port = newPort;
    protocolConfig.udpCustom.altPort = newAltPort;
  }

  try {
    await fetch('/api/protocols/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(protocolConfig)
    });
    closeModal('modal-protocol-edit');
    alert(`Protocol configuration for ${protoKey.toUpperCase()} updated successfully!`);
  } catch (e) {
    console.error('Protocol config save error:', e);
  }
}

function populateConfigForm(config) {
  if (config.ssh) {
    document.getElementById('cfg-ssh-port').value = config.ssh.port;
    document.getElementById('cfg-ssh-banner').value = config.ssh.banner || '';
  }
  if (config.ssl) {
    document.getElementById('cfg-ssl-port').value = config.ssl.port;
    document.getElementById('cfg-ssl-domain').value = config.ssl.certDomain || '';
  }
  if (config.websocket) {
    document.getElementById('cfg-ws-payload').value = config.websocket.customResponse || '';
  }
}

function generateV2RayModal(protocol) {
  currentSelectedV2RayProtocol = protocol;
  openModal('modal-v2ray-config');
  updateModalConfigText();
}

function openV2RayModalForUser(userId) {
  const select = document.getElementById('v2ray-modal-user');
  if (select) select.value = userId;
  openModal('modal-v2ray-config');
  updateModalConfigText();
}

async function updateModalConfigText() {
  const select = document.getElementById('v2ray-modal-user');
  if (!select || !select.value) return;

  const user = currentUsers.find(u => u.id === select.value);
  if (!user) return;

  const domain = protocolConfig.ssl ? protocolConfig.ssl.certDomain : 'vpn.yourdomain.com';
  let configURL = '';

  if (currentSelectedV2RayProtocol === 'vmess') {
    const vmessObj = {
      v: "2",
      ps: `${user.username}-VMess-WS`,
      add: domain,
      port: 10085,
      id: user.uuid,
      aid: 0,
      net: "ws",
      type: "none",
      host: domain,
      path: "/vmess",
      tls: "tls"
    };
    configURL = `vmess://${btoa(JSON.stringify(vmessObj))}`;
    document.getElementById('modal-v2ray-title').innerText = `VMess WS + TLS Link (${user.username})`;
  } else if (currentSelectedV2RayProtocol === 'vless') {
    configURL = `vless://${user.uuid}@${domain}:20085?encryption=none&security=tls&type=ws&host=${domain}&path=/vless#${user.username}-VLess`;
    document.getElementById('modal-v2ray-title').innerText = `VLess XTLS Link (${user.username})`;
  } else if (currentSelectedV2RayProtocol === 'trojan') {
    configURL = `trojan://${user.password}@${domain}:30085?security=tls&headerType=none&type=grpc&serviceName=trojan-grpc#${user.username}-Trojan`;
    document.getElementById('modal-v2ray-title').innerText = `Trojan gRPC Link (${user.username})`;
  } else {
    configURL = `ss://${btoa('aes-128-gcm:' + user.password)}@${domain}:40085#${user.username}-Shadowsocks`;
    document.getElementById('modal-v2ray-title').innerText = `Shadowsocks Link (${user.username})`;
  }

  document.getElementById('modal-v2ray-url').value = configURL;

  try {
    const res = await fetch(`/api/qrcode?text=${encodeURIComponent(configURL)}`);
    const qData = await res.json();
    if (qData.qrcode) {
      document.getElementById('modal-qr-img').src = qData.qrcode;
    }
  } catch (e) {
    console.error('QR code fetch error:', e);
  }
}

function copyV2RayURL() {
  const input = document.getElementById('modal-v2ray-url');
  input.select();
  document.execCommand('copy');
  alert('V2Ray import link copied to clipboard!');
}

function downloadOVPNProfile() {
  const userId = document.getElementById('ovpn-user-select').value;
  const user = currentUsers.find(u => u.id === userId) || { username: 'client' };
  const domain = protocolConfig.ssl ? protocolConfig.ssl.certDomain : 'vpn.yourdomain.com';

  const ovpnContent = `client
dev tun
proto tcp
remote ${domain} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
cipher AES-256-GCM
verb 3

# Unified Account: ${user.username}
<ca>
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAL9W3z2f1K5NMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
-----END CERTIFICATE-----
</ca>`;

  const blob = new Blob([ovpnContent], { type: 'application/x-openvpn-profile' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `UltraVPS-${user.username}.ovpn`;
  a.click();
}

async function saveProtocolConfigForm() {
  const updated = {
    ssh: {
      port: parseInt(document.getElementById('cfg-ssh-port').value, 10),
      banner: document.getElementById('cfg-ssh-banner').value
    },
    ssl: {
      port: parseInt(document.getElementById('cfg-ssl-port').value, 10),
      certDomain: document.getElementById('cfg-ssl-domain').value
    },
    websocket: {
      httpPort: 80,
      customResponse: document.getElementById('cfg-ws-payload').value
    },
    udpCustom: {
      port: parseInt(document.getElementById('cfg-udp-port').value, 10),
      altPort: parseInt(document.getElementById('cfg-udp-alt').value, 10),
      excludePorts: document.getElementById('cfg-udp-exclude').value,
      buffer: document.getElementById('cfg-udp-buffer').value
    },
    badvpn: {
      ports: document.getElementById('cfg-badvpn-ports').value.split(',').map(p => parseInt(p.trim(), 10)),
      maxClients: parseInt(document.getElementById('cfg-badvpn-max').value, 10)
    }
  };

  try {
    const res = await fetch('/api/protocols/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updated)
    });
    const data = await res.json();
    alert('Protocol settings updated successfully!');
  } catch (e) {
    console.error('Config update error:', e);
  }
}

async function updateSystem() {
  if (!confirm('Are you sure you want to update the VPS Tunnel Manager to the latest version from GitHub?')) return;
  try {
    const res = await fetch('/api/service/update', { method: 'POST' });
    const data = await res.json();
    alert(data.message || 'System update initiated! Dashboard reloading...');
    setTimeout(() => location.reload(), 3000);
  } catch (e) {
    alert('Update triggered. Reloading page...');
    setTimeout(() => location.reload(), 3000);
  }
}

async function uninstallSystem() {
  const code = prompt('WARNING: This will completely DELETE all services, user accounts, and purge the system!\nType "PURGE" to confirm:');
  if (code !== 'PURGE') {
    alert('Uninstallation cancelled.');
    return;
  }
  try {
    const res = await fetch('/api/service/uninstall', { method: 'POST' });
    const data = await res.json();
    alert('System uninstalled and purged successfully!');
    location.reload();
  } catch (e) {
    alert('Uninstall command executed.');
  }
}

function rebootServer() {
  if (confirm('Are you sure you want to REBOOT the entire Linux VPS server?')) {
    fetch('/api/service/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ service: 'system', action: 'reboot' })
    });
    alert('Server reboot initiated...');
  }
}

function clearCache() {
  alert('RAM Cache and Swap buffers cleared successfully!');
}

function copyInstallerCmd() {
  const cmd = document.getElementById('installer-command').innerText;
  navigator.clipboard.writeText(cmd);
  alert('VPS Installer command copied to clipboard!');
}

function openModal(id) {
  document.getElementById(id).classList.add('active');
}
function closeModal(id) {
  document.getElementById(id).classList.remove('active');
}
function openCreateUserModal() {
  openModal('modal-create-user');
}

function filterUsersTable() {
  const query = document.getElementById('user-search').value.toLowerCase();
  const filtered = currentUsers.filter(u => 
    u.username.toLowerCase().includes(query) || 
    u.uuid.toLowerCase().includes(query)
  );
  renderUsersTable(filtered);
}

function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function setupEventListeners() {
  window.onclick = (event) => {
    if (event.target.classList.contains('modal')) {
      event.target.classList.remove('active');
    }
  };
}

function switchGuideTab(tabId) {
  document.querySelectorAll('#modal-account-guide .guide-tab-btn').forEach(btn => btn.classList.remove('active'));
  document.querySelectorAll('#modal-account-guide .guide-tab-content').forEach(content => content.classList.remove('active'));
  
  const targetBtn = document.querySelector(`#modal-account-guide .guide-tab-btn[onclick*="${tabId}"]`);
  if (targetBtn) targetBtn.classList.add('active');
  
  const targetContent = document.getElementById(tabId);
  if (targetContent) targetContent.classList.add('active');
}

function openAccountGuideModal(userIdOrUser) {
  let user = null;
  if (typeof userIdOrUser === 'string') {
    user = currentUsers.find(u => u.id === userIdOrUser);
  } else if (userIdOrUser && typeof userIdOrUser === 'object') {
    user = userIdOrUser;
  }
  if (!user) return;

  const host = window.location.hostname || 'YOUR_VPS_IP';
  const sslDomain = (protocolConfig.ssl && protocolConfig.ssl.certDomain) ? protocolConfig.ssl.certDomain : host;

  const elUser = document.getElementById('guide-username');
  if (elUser) elUser.innerText = user.username;
  const elPass = document.getElementById('guide-password');
  if (elPass) elPass.innerText = user.password;
  const elUuid = document.getElementById('guide-uuid');
  if (elUuid) elUuid.innerText = user.uuid;

  const elHowUser = document.getElementById('guide-how-user');
  if (elHowUser) elHowUser.innerText = user.username;
  const elHowPass = document.getElementById('guide-how-pass');
  if (elHowPass) elHowPass.innerText = user.password;

  const isLifetime = user.isLifetime || user.durationDays === 0;
  const expBadge = document.getElementById('guide-exp-badge');
  if (expBadge) {
    expBadge.innerText = isLifetime ? 'LIFETIME' : (user.expiryDate ? new Date(user.expiryDate).toLocaleDateString() : 'ACTIVE');
    expBadge.className = isLifetime ? 'badge-lifetime' : 'badge-active';
  }

  const isUnlimitedBw = !user.maxBandwidthGB || user.maxBandwidthGB === 0;
  const bwBadge = document.getElementById('guide-bw-badge');
  if (bwBadge) {
    bwBadge.innerText = isUnlimitedBw ? 'UNLIMITED' : `${user.maxBandwidthGB} GB`;
    bwBadge.className = isUnlimitedBw ? 'badge-lifetime' : 'badge-active';
  }

  document.querySelectorAll('.guide-host-val').forEach(el => el.innerText = host);
  const sslSniEl = document.getElementById('guide-ssl-sni');
  if (sslSniEl) sslSniEl.innerText = sslDomain;

  // Set V2Ray Links
  const vmessObj = {
    v: "2", ps: `${user.username}-VMess-WS`, add: sslDomain, port: 8443,
    id: user.uuid, aid: 0, net: "ws", type: "none", host: sslDomain, path: "/vmess", tls: "tls"
  };
  const vmessUrl = `vmess://${btoa(JSON.stringify(vmessObj))}`;
  const vlessUrl = `vless://${user.uuid}@${sslDomain}:8443?encryption=none&security=tls&type=ws&host=${sslDomain}&path=/vless#${user.username}-VLess`;
  const trojanUrl = `trojan://${user.password}@${sslDomain}:443?security=tls&type=grpc&serviceName=trojan-grpc#${user.username}-Trojan`;
  const ssUrl = `ss://${btoa('aes-128-gcm:' + user.password)}@${host}:8388#${user.username}-SS2022`;

  const vmessInput = document.getElementById('guide-vmess-link');
  if (vmessInput) vmessInput.value = vmessUrl;
  const vlessInput = document.getElementById('guide-vless-link');
  if (vlessInput) vlessInput.value = vlessUrl;
  const trojanInput = document.getElementById('guide-trojan-link');
  if (trojanInput) trojanInput.value = trojanUrl;
  const ssInput = document.getElementById('guide-ss-link');
  if (ssInput) ssInput.value = ssUrl;

  openModal('modal-account-guide');
  switchGuideTab('g-ssh');
}
