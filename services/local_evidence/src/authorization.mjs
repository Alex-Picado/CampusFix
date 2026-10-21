import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

/** HTTP errors use stable public codes, without logging tokens or credentials. */
export class HttpError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}

/** Decodes Firestore REST fields without using privileged database credentials. */
function decode(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return value.timestampValue;
  return undefined;
}

/** Verifies Firebase sessions and reads permissions with the caller's ID token. */
export function firebaseAuthorization(config, { verifyToken, fetcher = fetch } = {}) {
  const verify = verifyToken ?? (async (token) => {
    const name = `local-evidence-${config.projectId}`;
    const app = getApps().find((candidate) => candidate.name === name) ??
      initializeApp({ projectId: config.projectId }, name);
    return getAuth(app).verifyIdToken(token);
  });
  return async (request, incidentId, writing, progressId) => {
    const bearer = /^Bearer ([^\s]+)$/.exec(request.headers.authorization ?? '');
    if (!bearer) throw new HttpError(401, 'unauthenticated');
    let identity;
    try { identity = await verify(bearer[1]); } catch { throw new HttpError(401, 'unauthenticated'); }
    if (!identity.uid) throw new HttpError(401, 'unauthenticated');
    const read = async (path) => {
      let response;
      try {
        response = await fetcher(`${config.firestoreOrigin}/v1/projects/${config.projectId}/databases/(default)/documents/${path}`,
          { headers: { Authorization: `Bearer ${bearer[1]}` }, signal: AbortSignal.timeout(8000) });
      } catch { throw new HttpError(503, 'unavailable'); }
      if (response.status === 404) return null;
      if (!response.ok) throw new HttpError(response.status === 401 ? 401 : response.status === 403 ? 403 : 503,
        response.status === 401 ? 'unauthenticated' : response.status === 403 ? 'permission_denied' : 'unavailable');
      const document = await response.json();
      return Object.fromEntries(Object.entries(document.fields ?? {}).map(([key, value]) => [key, decode(value)]));
    };
    const incident = await read(`incidents/${incidentId}`);
    if (!incident) throw new HttpError(404, 'not_found');
    if (writing) {
      const profile = await read(`users/${encodeURIComponent(identity.uid)}`);
      const reporter = progressId == null && profile?.role === 'reporter' && incident.createdByUserId === identity.uid;
      const technician = progressId != null && profile?.role === 'technician' &&
        incident.assignedTechnicianId === identity.uid && incident.status === 'EN_ATENCION';
      if (!reporter && !technician) throw new HttpError(403, 'permission_denied');
    }
    return { uid: identity.uid, read };
  };
}
