import { createHash, randomUUID } from 'node:crypto';
import { lstat, mkdir, readFile, realpath, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, join, relative, resolve, sep } from 'node:path';
import sharp from 'sharp';
import { HttpError } from './authorization.mjs';

export const maximumBytes = 3_000_000;
const types = { jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };
export const validId = (value) => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value) && !/^__.*__$/.test(value);

/** Fully decodes accepted photographs before retaining original bytes. */
export async function validateImage(bytes, contentType) {
  if (!bytes.length || bytes.length > maximumBytes) throw new HttpError(413, 'invalid_size');
  try {
    const image = sharp(bytes, { failOn: 'warning', limitInputPixels: 40_000_000, animated: false });
    const metadata = await image.metadata();
    if (!types[metadata.format] || types[metadata.format] !== contentType || (metadata.pages ?? 1) !== 1) {
      throw new Error('Unsupported image');
    }
    await image.stats();
  } catch { throw new HttpError(415, 'invalid_image'); }
}

/** Resolves an existing storage path while rejecting checkout symlinks. */
async function safeDirectory(root, incidentId) {
  await mkdir(root, { recursive: true });
  if ((await lstat(root)).isSymbolicLink()) throw new HttpError(500, 'storage_unavailable');
  const base = await realpath(root);
  const path = join(base, incidentId);
  await mkdir(path, { recursive: true });
  if ((await lstat(path)).isSymbolicLink() || dirname(await realpath(path)) !== base) {
    throw new HttpError(500, 'storage_unavailable');
  }
  return path;
}

/** Uses an atomic directory rename so bytes and their metadata become visible together. */
export async function storeImage(root, incidentId, evidenceId, record, bytes) {
  const parent = await safeDirectory(root, incidentId);
  const destination = join(parent, evidenceId);
  const digest = createHash('sha256').update(bytes).digest('hex');
  const complete = { ...record, digest };
  const existing = await loadImage(root, incidentId, evidenceId);
  if (existing) {
    if (JSON.stringify(existing.record) !== JSON.stringify(complete)) throw new HttpError(409, 'conflicting_upload');
    return existing.record;
  }
  const temporary = join(parent, `.upload-${randomUUID()}`);
  await mkdir(temporary);
  try {
    await writeFile(join(temporary, 'image'), bytes, { flag: 'wx' });
    await writeFile(join(temporary, 'metadata.json'), JSON.stringify(complete), { flag: 'wx' });
    try { await rename(temporary, destination); }
    catch (error) {
      const concurrent = await loadImage(root, incidentId, evidenceId);
      if (!concurrent || JSON.stringify(concurrent.record) !== JSON.stringify(complete)) {
        if (concurrent) throw new HttpError(409, 'conflicting_upload');
        throw error;
      }
    }
  } finally {
    const target = resolve(temporary);
    const within = relative(parent, target);
    if (!within.startsWith('..') && !within.includes(sep) && within.startsWith('.upload-')) {
      await rm(target, { recursive: true, force: true });
    }
  }
  return complete;
}

/** Loads only regular files inside the selected evidence directory. */
export async function loadImage(root, incidentId, evidenceId) {
  const directory = join(root, incidentId, evidenceId);
  try {
    const canonicalRoot = await realpath(root);
    if ((await lstat(root)).isSymbolicLink()) throw new HttpError(500, 'storage_unavailable');
    for (const path of [join(root, incidentId), directory, join(directory, 'image'), join(directory, 'metadata.json')]) {
      if ((await lstat(path)).isSymbolicLink()) throw new HttpError(500, 'storage_unavailable');
      const rel = relative(canonicalRoot, await realpath(path));
      if (rel.startsWith('..') || resolve(canonicalRoot, rel) !== await realpath(path)) throw new HttpError(500, 'storage_unavailable');
    }
    const record = JSON.parse(await readFile(join(directory, 'metadata.json'), 'utf8'));
    const bytes = await readFile(join(directory, 'image'));
    if (!Object.values(types).includes(record.contentType) || record.sizeBytes !== bytes.length ||
        record.id !== evidenceId || record.assetId !== `${incidentId}/${evidenceId}` ||
        bytes.length > maximumBytes || createHash('sha256').update(bytes).digest('hex') !== record.digest) {
      throw new HttpError(500, 'storage_unavailable');
    }
    return { record, bytes };
  } catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}
