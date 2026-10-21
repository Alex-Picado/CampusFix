import { createServer } from 'node:http';
import { mkdir } from 'node:fs/promises';
import { firebaseAuthorization, HttpError } from './authorization.mjs';
import { loadImage, maximumBytes, storeImage, validateImage, validId } from './storage.mjs';

/** Sends a small JSON response without caching or MIME type inference. */
function json(response, status, body) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}

/** Handles local health checks and authenticated image uploads/downloads. */
export function createEvidenceServer(config, { authorize = firebaseAuthorization(config) } = {}) {
  return createServer({ requestTimeout: 30_000, headersTimeout: 10_000 }, (request, response) => {
    const handle = async () => {
      response.setHeader('Cache-Control', 'no-store');
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('Vary', 'Origin');
      const origin = request.headers.origin;
      if (origin !== undefined && !config.allowedOrigins.includes(origin)) {
        json(response, 403, { error: 'origin_not_allowed' });
        return;
      }
      if (origin !== undefined) response.setHeader('Access-Control-Allow-Origin', origin);
      if (request.method === 'OPTIONS') {
        response.writeHead(204, {
          'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-File-Name, X-Progress-Id',
        });
        response.end();
      } else if (request.method === 'GET' && request.url === '/health') {
        json(response, 200, { status: 'ok', service: 'campusfix-local-evidence' });
      } else if (/^\/incidents\/[^/]+\/evidence\/[^/]+$/.test(request.url ?? '') && ['GET', 'PUT'].includes(request.method)) {
        const [, , incidentId, , evidenceId] = request.url.split('/');
        const progressId = request.headers['x-progress-id'] ?? null;
        if (!validId(incidentId) || !validId(evidenceId) || (progressId !== null && !validId(progressId))) {
          throw new HttpError(400, 'invalid_id');
        }
        const context = await authorize(request, incidentId, request.method === 'PUT', progressId);
        if (request.method === 'PUT') {
          const contentType = request.headers['content-type'];
          if (!['image/jpeg', 'image/png', 'image/webp'].includes(contentType)) throw new HttpError(415, 'invalid_image');
          let fileName;
          try { fileName = decodeURIComponent(request.headers['x-file-name'] ?? 'photo'); } catch { throw new HttpError(400, 'invalid_name'); }
          if (!fileName.trim() || fileName.length > 160 || /[\x00-\x1f\x7f/\\]/.test(fileName)) throw new HttpError(400, 'invalid_name');
          if (Number(request.headers['content-length']) > maximumBytes) throw new HttpError(413, 'invalid_size');
          const chunks = [];
          let size = 0;
          for await (const chunk of request) {
            size += chunk.length;
            if (size > maximumBytes) throw new HttpError(413, 'invalid_size');
            chunks.push(chunk);
          }
          const bytes = Buffer.concat(chunks);
          await validateImage(bytes, contentType);
          // Recheck live role, assignment and state after receiving and decoding bytes.
          await authorize(request, incidentId, true, progressId);
          const reference = { id: evidenceId, assetId: `${incidentId}/${evidenceId}`, url: request.url,
            fileName, contentType, sizeBytes: bytes.length, progressId };
          await storeImage(config.storageDirectory, incidentId, evidenceId, { ...reference, uploadedByUserId: context.uid }, bytes);
          json(response, 200, reference);
        } else {
          const file = await loadImage(config.storageDirectory, incidentId, evidenceId);
          if (!file) throw new HttpError(404, 'not_found');
          const metadata = await context.read(`incidents/${incidentId}/evidence/${evidenceId}`);
          if (!metadata && file.record.uploadedByUserId !== context.uid) throw new HttpError(404, 'not_found');
          if (metadata && (metadata.assetId !== file.record.assetId || metadata.uploadedByUserId !== file.record.uploadedByUserId)) {
            throw new HttpError(403, 'permission_denied');
          }
          response.writeHead(200, { 'Content-Type': file.record.contentType, 'Content-Length': file.bytes.length });
          response.end(file.bytes);
        }
      } else {
        json(response, 404, { error: 'not_found' });
      }
    };
    handle().catch((error) => {
      if (!response.headersSent) json(response, error.status ?? 500, { error: error.code && error.status ? error.code : 'unavailable' });
      else response.destroy();
    });
  });
}

/** Ensures persistent storage exists before opening the configured listener. */
export async function startEvidenceService(config, dependencies) {
  await mkdir(config.storageDirectory, { recursive: true });
  const server = createEvidenceServer(config, dependencies);
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(config.port, config.host, () => {
      server.removeListener('error', reject);
      resolve();
    });
  });
  return server;
}
