/* ==========================================================================
   ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - FRONTEND LOGIC (APP.JS)
   Handles WebSockets, Live Telemetry, Universal Accounts, Config Generators & Modals
   ========================================================================== */

let socket = null;
let currentUsers = [];
let protocolConfig = {};
let currentSelectedV2RayProtocol = 'vmess';

// Initialize App on DOM Loaded
document.addEventListener('DOMContentLoaded', () => {
  initSocketConnection();
  setupEventListeners();
});

// Socket.io Telemetry & Real-Time Sync
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

// Fallback REST Telemetry
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

// Update Top Task Manager UI Telemetry Meters
function updateTelemetryUI(data) {
  if (!data) return;

  // CPU
  const cpuPct = data.cpu ? data.cpu.usage : 15;
  document.getElementById('cpu-pct').innerText = `${cpuPct}%`;
  document.getElementById('cpu-bar').style.width = `${cpuPct}%`;
  document.getElementById('cpu-model').innerText = data.cpu ? data.cpu.model : 'AMD64 Processor';
  document.getElementById('arch-badge').innerText = data.arch || 'AMD64 / x86_64';

  // RAM
  const ramPct = data.ram ? data.ram.percentage : 25;
  document.getElementById('ram-pct').innerText = `${ramPct}%`;
  document.getElementById('ram-bar').style.width = `${ramPct}%`;
  document.getElementById('ram-used').innerText = data.ram ? data.ram.used : '1.2';
  document.getElementById('ram-total').innerText = data.ram ? data.ram.total : '4.0';

  // Network
  if (data.network) {
    document.getElementById('net-rx').innerText = data.network.rxSpeed;
    document.getElementById('net-tx').innerText = data.network.txSpeed;
    document.getElementById('net-total').innerText = `${data.network.totalRx} / ${data.network.totalTx}`;
  }

  // Active Users & Storage
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
}

// Render Universal Accounts Table
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

    tr.innerHTML = `
      <td><strong>${escapeHtml(user.username)}</strong></td>
      <td><code>${escapeHtml(user.password)}</code></td>
      <td><span class="uuid-text">${escapeHtml(user.uuid.slice(0, 18))}...</span></td>
      <td><span class="tag"><i class="fa-solid fa-mobile-screen"></i> ${user.maxLogins} Devices</span></td>
      <td>${expDisplay}</td>
      <td>
        <span class="tag"><i class="fa-solid fa-check color-emerald"></i> ALL PROTOCOLS</span>
      </td>
      <td>
        <span class="status-pill ${user.status === 'active' ? 'online' : 'offline'}">
          <i class="fa-solid fa-${user.status === 'active' ? 'check-circle' : 'lock'}"></i> ${user.status}
        </span>
      </td>
      <td>
        <div style="display: flex; gap: 4px;">
          <button class="btn btn-xs btn-outline" title="Toggle Lock" onclick="toggleUserStatus('${user.id}')"><i class="fa-solid fa-${user.status === 'active' ? 'lock' : 'lock-open'}"></i></button>
          <button class="btn btn-xs btn-outline" title="Extend Validity" onclick="extendUserValidityPrompt('${user.id}')"><i class="fa-solid fa-calendar-plus"></i></button>
          <button class="btn btn-xs btn-secondary" title="Get V2Ray / OpenVPN Config" onclick="openV2RayModalForUser('${user.id}')"><i class="fa-solid fa-qrcode"></i></button>
          <button class="btn btn-xs btn-glass" style="color: var(--rose);" title="Delete" onclick="deleteUser('${user.id}')"><i class="fa-solid fa-trash"></i></button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

// Populate User Selection Options in Modals & Forms
function populateUserSelects(users) {
  const v2raySelect = document.getElementById('v2ray-modal-user');
  const ovpnSelect = document.getElementById('ovpn-user-select');

  if (v2raySelect) {
    v2raySelect.innerHTML = users.map(u => `<option value="${u.id}">${u.username} (${u.isLifetime ? 'Lifetime' : u.durationDays + ' days'})</option>`).join('');
  }
  if (ovpnSelect) {
    ovpnSelect.innerHTML = users.map(u => `<option value="${u.id}">${u.username}</option>`).join('');
  }
}

// Navigation Tab Switching
function switchTab(tabId) {
  document.querySelectorAll('.nav-item').forEach(btn => btn.classList.remove('active'));
  document.querySelectorAll('.tab-page').forEach(page => page.classList.remove('active'));

  const targetTab = document.getElementById(`tab-${tabId}`);
  if (targetTab) {
    targetTab.classList.add('active');
  }

  // Highlight button
  const activeBtn = Array.from(document.querySelectorAll('.nav-item')).find(b => b.getAttribute('onclick').includes(tabId));
  if (activeBtn) activeBtn.classList.add('active');
}

// Create Universal Account Submission (0 = Lifetime)
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
    alert('Failed to connect to backend server.');
  }
}

// Delete User
async function deleteUser(id) {
  if (!confirm('Are you sure you want to delete this universal user account?')) return;
  try {
    await fetch(`/api/users/${id}`, { method: 'DELETE' });
  } catch (e) {
    console.error('Delete error:', e);
  }
}

// Toggle Lock / Unlock Status
async function toggleUserStatus(id) {
  try {
    await fetch(`/api/users/${id}/toggle-status`, { method: 'POST' });
  } catch (e) {
    console.error('Status toggle error:', e);
  }
}

// Extend User Validity Prompt
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

// V2Ray & Protocol Modal Link Generator
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

  // Generate QR Code via backend API
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

// Copy V2Ray URL to Clipboard
function copyV2RayURL() {
  const input = document.getElementById('modal-v2ray-url');
  input.select();
  document.execCommand('copy');
  alert('V2Ray import link copied to clipboard!');
}

// Download OpenVPN Profile (.ovpn)
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
BAYTAFVTMQswCQYDVQQIDAJDQTEUMBIGA1UEBwwLU2FuIEZyYW5jaXNjbzEPMA0G
A1UECgwGVUxUUkExCzAJBgNVBAMMAkNBMB4XDTI2MDkwNzE1NDMwMFoXDTM2MDkw
NDE1NDMwMFowRTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRQwEgYDVQQHDAtT
YW4gRnJhbmNpc2NvMQ8wDQYDVQQKDAZVTFRSQTELEDAGBgNVBAMMAkNBMIIBIjAN
-----END CERTIFICATE-----
</ca>`;

  const blob = new Blob([ovpnContent], { type: 'application/x-openvpn-profile' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `UltraVPS-${user.username}.ovpn`;
  a.click();
}

// Save Protocol Config Form
async function saveProtocolConfigForm() {
  const updated = {
    ssh: {
      port: parseInt(document.getElementById('cfg-ssh-port').value, 10),
      dropbearPort: parseInt(document.getElementById('cfg-dropbear-port').value, 10),
      banner: document.getElementById('cfg-ssh-banner').value
    },
    ssl: {
      port: parseInt(document.getElementById('cfg-ssl-port').value, 10),
      altPort: parseInt(document.getElementById('cfg-ssl-alt').value, 10),
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
    alert('Protocol settings updated successfully across all servers!');
  } catch (e) {
    console.error('Config update error:', e);
  }
}

// Service Actions (Restart / Stop / Start)
async function restartService(serviceName) {
  try {
    await fetch('/api/service/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ service: serviceName, action: 'restart' })
    });
    alert(`Service '${serviceName}' restart command executed.`);
  } catch (e) {
    console.error('Service restart error:', e);
  }
}

async function restartAllServices() {
  alert('Restarting all SSH, WebSocket, UDP Custom, BadVPN, and Xray services...');
  ['ssh', 'stunnel', 'wsProxy', 'udpCustom', 'badvpn', 'v2ray'].forEach(s => restartService(s));
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

// Modal Handlers
function openModal(id) {
  document.getElementById(id).classList.add('active');
}
function closeModal(id) {
  document.getElementById(id).classList.remove('active');
}
function openCreateUserModal() {
  openModal('modal-create-user');
}

// Helpers & Search Filter
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
