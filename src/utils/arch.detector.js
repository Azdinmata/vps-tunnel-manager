const os = require('os');

/**
 * Detect CPU Processor Architecture (AMD64 / Intel x86_64 vs ARM64)
 */
function getArchitecture() {
  const arch = os.arch();
  if (arch === 'x64') return 'AMD64 / x86_64';
  if (arch === 'arm64') return 'ARM64 / aarch64';
  return arch;
}

module.exports = { getArchitecture };
