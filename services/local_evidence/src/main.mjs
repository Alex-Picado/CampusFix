import { readConfig, verifyRuntime } from './config.mjs';
import { startEvidenceService } from './server.mjs';

/** Starts the local service and closes its listener on a termination signal. */
async function main() {
  verifyRuntime();
  const config = readConfig();
  const server = await startEvidenceService(config);
  server.on('error', (error) => {
    console.error(`Local evidence server error: ${error.message}`);
    process.exitCode = 1;
    server.close();
  });
  const host = config.host === '::1' ? '[::1]' : config.host;
  console.log(`Local evidence service listening at http://${host}:${config.port}`);
  let stopping = false;
  const stop = () => {
    if (stopping) return;
    stopping = true;
    server.close();
    server.closeIdleConnections();
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

main().catch((error) => {
  console.error(`Local evidence service could not start: ${error.message}`);
  process.exitCode = 1;
});
