import admin from '../firebase.js';
import User from '../models/User.js';
import jwt from 'jsonwebtoken';
import { ObjectId } from 'mongodb';

function extractBearerToken(headerValue) {
  if (!headerValue || typeof headerValue !== 'string') {
    return null;
  }
  const trimmed = headerValue.trim();
  if (!trimmed.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  const token = trimmed.slice(7).trim();
  return token.length ? token : null;
}

const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret_change_me';

function buildIdFilterFromPayloadId(value) {
  if (!value) return null;
  if (value instanceof ObjectId) {
    return { _id: value };
  }
  const raw = String(value).trim();
  if (!raw.length) return null;
  if (ObjectId.isValid(raw)) {
    return { _id: new ObjectId(raw) };
  }
  return { _id: raw };
}

async function resolveFirebaseAuthContext(req, token) {
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.firebaseUser = decoded;
    const findClauses = [{ firebaseUid: decoded.uid }];
    if (decoded.email) {
      findClauses.push({ email: decoded.email.trim().toLowerCase() });
    }

    const filter = findClauses.length > 1 ? { $or: findClauses } : findClauses[0];
    let user = await User.findOne(filter);

    if (!user) {
      user = await User.create({
        firebaseUid: decoded.uid,
        email: decoded.email?.trim().toLowerCase() ?? null,
        role: 'customer',
      });
    } else if (!user.firebaseUid) {
      user = await User.updateFirebaseUid(user._id, decoded.uid);
    }

    req.appUser = user;
    return { ok: true };
  } catch (error) {
    return { ok: false, error };
  }
}

function extractUserIdFromJwt(payload) {
  if (!payload || typeof payload !== 'object') return null;
  return payload.sub ?? payload._id ?? payload.id ?? null;
}

async function resolveLegacyJwtContext(req, token) {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const candidateId = extractUserIdFromJwt(decoded);
    const filter = buildIdFilterFromPayloadId(candidateId);
    if (!filter) {
      return { ok: false, error: new Error('Missing user id in JWT payload') };
    }

    const user = await User.findOne(filter);
    if (!user) {
      return { ok: false, error: new Error('User not found for JWT payload') };
    }

    if (!req.user) {
      req.user = decoded;
    }
    req.appUser = user;
    return { ok: true };
  } catch (error) {
    return { ok: false, error };
  }
}

export async function authMiddleware(req, res, next) {
  const token = extractBearerToken(req.headers?.authorization || '');
  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }

  const firebaseResult = await resolveFirebaseAuthContext(req, token);
  if (firebaseResult.ok) {
    req.authToken = token;
    return next();
  }

  const legacyResult = await resolveLegacyJwtContext(req, token);
  if (legacyResult.ok) {
    req.authToken = token;
    return next();
  }

  const errorToLog = legacyResult.error ?? firebaseResult.error;
  if (errorToLog) {
    console.error('[authMiddleware] Failed to verify token', errorToLog);
  }
  return res.status(401).json({ message: 'Invalid token' });
}
