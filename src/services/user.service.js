const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');
const { generateUUID } = require('../utils/uuid.generator');

const DB_FILE = path.join(__dirname, '../../users_db.json');

class UserService {
  constructor() {
    this.users = this.loadDB();
  }

  loadDB() {
    if (fs.existsSync(DB_FILE)) {
      try {
        return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
      } catch (e) {
        console.error('Error loading user DB:', e);
      }
    }
    return [
      {
        id: "usr_1",
        username: "demo_vip",
        password: "Password123!",
        uuid: "e4a781b2-93c4-4b52-a1e9-8f7d6c5b4a3e",
        maxLogins: 3,
        durationDays: 30,
        createdDate: new Date().toISOString(),
        expiryDate: new Date(Date.now() + 30 * 86400000).toISOString(),
        isLifetime: false,
        status: "active",
        protocols: ["ssh", "ssl", "ws", "udp_custom", "badvpn", "v2ray", "openvpn", "slowdns"]
      },
      {
        id: "usr_2",
        username: "pro_lifetime",
        password: "LifetimePass99!",
        uuid: "a1b2c3d4-e5f6-4789-8a9b-c0d1e2f3a4b5",
        maxLogins: 10,
        durationDays: 0, // 0 = Lifetime
        createdDate: new Date().toISOString(),
        expiryDate: "LIFETIME",
        isLifetime: true,
        status: "active",
        protocols: ["ssh", "ssl", "ws", "udp_custom", "badvpn", "v2ray", "openvpn", "slowdns"]
      }
    ];
  }

  saveDB() {
    fs.writeFileSync(DB_FILE, JSON.stringify(this.users, null, 2));
  }

  getAllUsers() {
    return this.users;
  }

  createUser({ username, password, maxLogins, durationDays }) {
    const existing = this.users.find(u => u.username.toLowerCase() === username.toLowerCase());
    if (existing) throw new Error("Username already exists!");

    const days = parseInt(durationDays, 10);
    const isLifetime = (days === 0 || isNaN(days));
    const createdDate = new Date();
    let expiryDate = "LIFETIME";

    if (!isLifetime) {
      expiryDate = new Date(createdDate.getTime() + days * 86400000).toISOString();
    }

    const newUser = {
      id: `usr_${Date.now()}`,
      username,
      password,
      uuid: generateUUID(username),
      maxLogins: parseInt(maxLogins, 10) || 2,
      durationDays: isLifetime ? 0 : days,
      createdDate: createdDate.toISOString(),
      expiryDate,
      isLifetime,
      status: "active",
      protocols: ["ssh", "ssl", "ws", "udp_custom", "badvpn", "v2ray", "openvpn", "slowdns"]
    };

    this.users.push(newUser);
    this.saveDB();

    if (os.platform() === 'linux') {
      try {
        execSync(`useradd -e ${isLifetime ? '""' : expiryDate.slice(0,10)} -M -s /bin/false "${username}"`);
        execSync(`echo "${username}:${password}" | chpasswd`);
      } catch (e) {}
    }

    return newUser;
  }

  deleteUser(id) {
    const user = this.users.find(u => u.id === id);
    if (!user) throw new Error("User not found");

    this.users = this.users.filter(u => u.id !== id);
    this.saveDB();

    if (os.platform() === 'linux') {
      try { execSync(`userdel -f "${user.username}"`); } catch (e) {}
    }

    return true;
  }

  toggleUserStatus(id) {
    const user = this.users.find(u => u.id === id);
    if (!user) throw new Error("User not found");

    user.status = user.status === "active" ? "locked" : "active";
    this.saveDB();

    if (os.platform() === 'linux') {
      try {
        if (user.status === 'locked') execSync(`usermod -L "${user.username}"`);
        else execSync(`usermod -U "${user.username}"`);
      } catch (e) {}
    }

    return user;
  }

  extendValidity(id, additionalDays) {
    const user = this.users.find(u => u.id === id);
    if (!user) throw new Error("User not found");

    const add = parseInt(additionalDays, 10);
    if (add === 0) {
      user.isLifetime = true;
      user.durationDays = 0;
      user.expiryDate = "LIFETIME";
    } else {
      user.isLifetime = false;
      let baseDate = user.expiryDate === "LIFETIME" ? new Date() : new Date(user.expiryDate);
      if (isNaN(baseDate.getTime())) baseDate = new Date();
      const newExp = new Date(baseDate.getTime() + add * 86400000);
      user.expiryDate = newExp.toISOString();
      user.durationDays = Math.ceil((newExp - new Date()) / 86400000);
    }

    this.saveDB();
    return user;
  }
}

module.exports = new UserService();
