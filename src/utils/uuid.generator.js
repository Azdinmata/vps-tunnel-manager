/**
 * Generate a deterministic UUID v4 string from username for V2Ray synchronization
 */
function generateUUID(username) {
  let hash = 0;
  for (let i = 0; i < username.length; i++) {
    hash = ((hash << 5) - hash) + username.charCodeAt(i);
    hash |= 0;
  }
  const hex = Math.abs(hash).toString(16).padStart(8, '0');
  return `${hex.slice(0,8)}-4000-8000-${hex.slice(0,4)}-${hex.padStart(12, 'f').slice(0,12)}`;
}

module.exports = { generateUUID };
