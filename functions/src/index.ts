import { createHash } from 'node:crypto';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';
import { initializeApp } from 'firebase-admin/app';
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';

initializeApp();

const db = getFirestore();
const REGION = 'europe-west1';
const WEB_ORIGINS = [
  'https://salo-production-13fae.web.app',
  'https://salo-production-13fae.firebaseapp.com',
];
const CALLABLE_OPTIONS = {
  region: REGION,
  cors: WEB_ORIGINS,
  maxInstances: 20,
} as const;
const MAX_CALLABLE_PAYLOAD_BYTES = 2 * 1024 * 1024;

function enforcePayloadLimit(request: CallableRequest<unknown>): void {
  const declaredLength = Number(request.rawRequest.headers['content-length'] ?? 0);
  const measuredLength = Buffer.byteLength(JSON.stringify(request.data ?? null), 'utf8');
  if (declaredLength > MAX_CALLABLE_PAYLOAD_BYTES || measuredLength > MAX_CALLABLE_PAYLOAD_BYTES) {
    throw new HttpsError('invalid-argument', 'حجم الطلب يتجاوز الحد المسموح (2MB).');
  }
}

function requireAuth(
  request: CallableRequest<unknown>,
  requireVerifiedEmail = true,
): { uid: string; token: DecodedIdToken } {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'سجّل الدخول أولاً.');
  }
  if (requireVerifiedEmail && auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'تحقق من بريدك الإلكتروني أولاً.');
  }
  return { uid: auth.uid, token: auth.token as DecodedIdToken };
}

function dataObject(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'صيغة الطلب غير صحيحة.');
  }
  return value as Record<string, unknown>;
}

function textValue(value: unknown, label: string, maxLength: number): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `${label} غير صالح.`);
  }
  const cleaned = value
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '')
    .trim();
  if (cleaned.length === 0 || cleaned.length > maxLength) {
    throw new HttpsError('invalid-argument', `${label} يجب أن يكون بين 1 و${maxLength} حرفاً.`);
  }
  return cleaned;
}

function normalizeUsername(value: unknown): { username: string; key: string } {
  const username = textValue(value, 'اسم المستخدم', 32);
  const key = username.normalize('NFKC').toLowerCase();
  if ([...key].length < 3 || !/^[\p{L}\p{N}_.]{3,32}$/u.test(key)) {
    throw new HttpsError(
      'invalid-argument',
      'اسم المستخدم يجب أن يكون 3–32 حرفاً أو رقماً، ويمكنه احتواء النقطة والشرطة السفلية فقط.',
    );
  }
  return { username, key };
}

function stableId(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

async function consumeRateLimit(
  uid: string,
  action: string,
  limit: number,
  windowMs: number,
): Promise<void> {
  const now = Date.now();
  const ref = db.collection('_serverRateLimits').doc(stableId(`${uid}:${action}`));
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.data();
    const startedAt = typeof current?.windowStartedAtMs === 'number'
      ? current.windowStartedAtMs
      : 0;
    const count = typeof current?.count === 'number' ? current.count : 0;

    if (!snapshot.exists || now - startedAt >= windowMs) {
      transaction.set(ref, {
        action,
        count: 1,
        windowStartedAtMs: now,
        expiresAt: Timestamp.fromMillis(now + windowMs * 3),
      });
      return;
    }
    if (count >= limit) {
      throw new HttpsError('resource-exhausted', 'تم تجاوز الحد المؤقت للطلبات. حاول لاحقاً.');
    }
    transaction.update(ref, {
      count: FieldValue.increment(1),
      expiresAt: Timestamp.fromMillis(now + windowMs * 3),
    });
  });
}

async function requireProfile(uid: string): Promise<DocumentData> {
  const snapshot = await db.collection('users').doc(uid).get();
  if (!snapshot.exists) {
    throw new HttpsError('failed-precondition', 'أكمل إعداد ملفك الشخصي أولاً.');
  }
  return snapshot.data() ?? {};
}

function millis(value: unknown): number {
  return value instanceof Timestamp ? value.toMillis() : 0;
}

function serializeStory(snapshot: QueryDocumentSnapshot): Record<string, unknown> {
  const data = snapshot.data();
  return {
    id: snapshot.id,
    ownerUid: data.ownerUid,
    authorName: data.authorName,
    type: data.type,
    text: data.text,
    visibility: data.visibility,
    createdAtMillis: millis(data.createdAt),
    expiresAtMillis: millis(data.expiresAt),
  };
}

export const checkAuthRateLimit = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const input = dataObject(request.data);
  const action = input.action;
  if (action !== 'login' && action !== 'register' && action !== 'password_reset') {
    throw new HttpsError('invalid-argument', 'نوع محاولة المصادقة غير صالح.');
  }
  const email = textValue(input.email, 'البريد الإلكتروني', 254).toLowerCase();
  const ip = request.rawRequest.ip || 'unknown-client';
  const emailLimit = action === 'register' ? 5 : 12;
  await Promise.all([
    consumeRateLimit(stableId(`email:${email}`), `auth_${action}_email`, emailLimit, 60 * 60 * 1000),
    consumeRateLimit(stableId(`ip:${ip}`), `auth_${action}_ip`, 30, 60 * 60 * 1000),
  ]);
  return { allowed: true };
});

export const createUserProfile = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid, token } = requireAuth(request, false);
  const input = dataObject(request.data);
  const { username, key } = normalizeUsername(input.username);
  const displayName = textValue(input.displayName, 'الاسم الظاهر', 64);
  const email = typeof token.email === 'string' ? token.email.trim().toLowerCase() : '';
  if (!email) {
    throw new HttpsError('failed-precondition', 'أضف بريداً إلكترونياً إلى حسابك.');
  }

  await consumeRateLimit(uid, 'profile_setup', 5, 60 * 60 * 1000);
  const userRef = db.collection('users').doc(uid);
  const usernameRef = db.collection('usernames').doc(key);
  const privateRef = db.collection('privateUsers').doc(uid);

  await db.runTransaction(async (transaction) => {
    const [userSnapshot, usernameSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(usernameRef),
    ]);
    if (userSnapshot.exists) {
      const existing = userSnapshot.data() ?? {};
      if (existing.usernameNormalized === key) return;
      throw new HttpsError('already-exists', 'هذا الحساب لديه اسم مستخدم مسجل بالفعل.');
    }
    if (usernameSnapshot.exists && usernameSnapshot.get('uid') !== uid) {
      throw new HttpsError('already-exists', 'اسم المستخدم مستخدم بالفعل. اختر اسماً آخر.');
    }
    const now = FieldValue.serverTimestamp();
    transaction.create(usernameRef, { uid, username, usernameNormalized: key, createdAt: now });
    transaction.create(userRef, {
      uid,
      username,
      usernameNormalized: key,
      displayName,
      photoUrl: null,
      createdAt: now,
      updatedAt: now,
    });
    transaction.set(privateRef, {
      email,
      emailVerified: token.email_verified === true,
      updatedAt: now,
    }, { merge: true });
  });

  const authUser = await getAuth().getUser(uid);
  if (authUser.customClaims?.role == null) {
    await getAuth().setCustomUserClaims(uid, { ...authUser.customClaims, role: 'user' });
  }
  return { uid, username, profileReady: true };
});

export const startDirectChat = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const { key } = normalizeUsername(input.username);
  await consumeRateLimit(uid, 'start_direct_chat', 20, 60 * 60 * 1000);

  const usernameSnapshot = await db.collection('usernames').doc(key).get();
  const peerUid = usernameSnapshot.get('uid');
  if (typeof peerUid !== 'string' || peerUid === uid) {
    throw new HttpsError('not-found', 'لم يتم العثور على مستخدم بهذا الاسم.');
  }
  const [selfProfile, peerProfile, ownBlock, peerBlock] = await Promise.all([
    requireProfile(uid),
    requireProfile(peerUid),
    db.doc(`blocks/${uid}/users/${peerUid}`).get(),
    db.doc(`blocks/${peerUid}/users/${uid}`).get(),
  ]);
  if (ownBlock.exists || peerBlock.exists) {
    throw new HttpsError('permission-denied', 'لا يمكن بدء محادثة مع هذا المستخدم.');
  }

  const members = [uid, peerUid].sort();
  const chatId = stableId(`direct:${members.join(':')}`);
  const chatRef = db.collection('chats').doc(chatId);
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(chatRef);
    if (existing.exists) {
      const existingMembers = existing.get('memberUids');
      if (!Array.isArray(existingMembers) || members.some((member) => !existingMembers.includes(member))) {
        throw new HttpsError('permission-denied', 'تعذر فتح هذه المحادثة.');
      }
      return;
    }
    const now = FieldValue.serverTimestamp();
    transaction.create(chatRef, {
      kind: 'direct',
      memberUids: members,
      participants: {
        [uid]: {
          username: selfProfile.username,
          displayName: selfProfile.displayName,
        },
        [peerUid]: {
          username: peerProfile.username,
          displayName: peerProfile.displayName,
        },
      },
      lastMessage: 'لا توجد رسائل',
      createdAt: now,
      updatedAt: now,
    });
  });
  return { chatId };
});

export const sendMessage = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const chatId = textValue(input.chatId, 'معرّف المحادثة', 128);
  const text = textValue(input.text, 'نص الرسالة', 2000);
  const clientMessageId = typeof input.clientMessageId === 'string'
    && /^[A-Za-z0-9_-]{8,80}$/.test(input.clientMessageId)
    ? input.clientMessageId
    : db.collection('_ids').doc().id;

  await consumeRateLimit(uid, 'send_message', 60, 60 * 1000);
  const chatRef = db.collection('chats').doc(chatId);
  const chat = await chatRef.get();
  const memberUids = chat.get('memberUids');
  if (!chat.exists || !Array.isArray(memberUids) || !memberUids.includes(uid)) {
    throw new HttpsError('permission-denied', 'لا تملك صلاحية إرسال رسالة إلى هذه المحادثة.');
  }
  if (memberUids.length > 100) {
    throw new HttpsError('failed-precondition', 'المحادثة تتجاوز الحد المدعوم للأعضاء.');
  }
  const otherUids = memberUids.filter((memberUid: unknown) => typeof memberUid === 'string' && memberUid !== uid) as string[];
  const blockRefs = otherUids.flatMap((otherUid) => [
    db.doc(`blocks/${uid}/users/${otherUid}`),
    db.doc(`blocks/${otherUid}/users/${uid}`),
  ]);
  if (blockRefs.length > 0) {
    const blockSnapshots = await db.getAll(...blockRefs);
    if (blockSnapshots.some((snapshot) => snapshot.exists)) {
      throw new HttpsError('permission-denied', 'لا يمكن إرسال الرسالة بسبب إعدادات الحظر.');
    }
  }

  const messageRef = chatRef.collection('messages').doc(clientMessageId);
  await db.runTransaction(async (transaction) => {
    const [freshChat, existingMessage] = await Promise.all([
      transaction.get(chatRef),
      transaction.get(messageRef),
    ]);
    const currentMembers = freshChat.get('memberUids');
    if (!freshChat.exists || !Array.isArray(currentMembers) || !currentMembers.includes(uid)) {
      throw new HttpsError('permission-denied', 'لم تعد عضواً في هذه المحادثة.');
    }
    if (existingMessage.exists) {
      if (existingMessage.get('senderUid') === uid) return;
      throw new HttpsError('already-exists', 'معرّف الرسالة مستخدم.');
    }
    const now = FieldValue.serverTimestamp();
    transaction.create(messageRef, {
      senderUid: uid,
      type: 'text',
      text,
      createdAt: now,
    });
    transaction.update(chatRef, {
      lastMessage: text.slice(0, 160),
      lastMessageAt: now,
      updatedAt: now,
    });
  });
  return { messageId: clientMessageId };
});

export const createStory = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const type = input.type ?? 'text';
  if (type !== 'text') {
    throw new HttpsError('invalid-argument', 'النوع المسموح حالياً للستوري هو النص فقط.');
  }
  const text = textValue(input.text, 'نص الستوري', 1000);
  const visibility = input.visibility === 'public' ? 'public' : 'friends';
  await consumeRateLimit(uid, 'create_story', 5, 60 * 60 * 1000);
  const profile = await requireProfile(uid);
  const now = Timestamp.now();
  const ref = await db.collection('stories').add({
    ownerUid: uid,
    authorName: typeof profile.displayName === 'string' ? profile.displayName : 'SALO user',
    type: 'text',
    text,
    visibility,
    createdAt: now,
    expiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
  });
  return { storyId: ref.id };
});

export const listStories = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  await consumeRateLimit(uid, 'list_stories', 30, 60 * 1000);
  const now = Timestamp.now();
  const friendSnapshot = await db.collection('friends').doc(uid).collection('users')
    .where('status', '==', 'accepted').limit(50).get();
  const blockedSnapshot = await db.collection('blocks').doc(uid).collection('users').limit(100).get();
  const blocked = new Set(blockedSnapshot.docs.map((doc) => doc.id));
  let friends = friendSnapshot.docs.map((doc) => doc.id).filter((friendUid) => !blocked.has(friendUid));

  // Batched reads verify reciprocal accepted friendships and blocks; story cards
  // contain author snapshots, so no per-story user lookups are needed.
  if (friends.length > 0) {
    const relationshipRefs = friends.flatMap((friendUid) => [
      db.doc(`friends/${friendUid}/users/${uid}`),
      db.doc(`blocks/${friendUid}/users/${uid}`),
    ]);
    const relationships = await db.getAll(...relationshipRefs);
    friends = friends.filter((_, index) =>
      relationships[index * 2]?.get('status') === 'accepted'
      && !relationships[index * 2 + 1]?.exists,
    );
  }

  const queries: Promise<{ docs: QueryDocumentSnapshot[] }>[] = [
    db.collection('stories').where('ownerUid', '==', uid)
      .where('expiresAt', '>', now).orderBy('expiresAt').limit(30).get(),
    db.collection('stories').where('visibility', '==', 'public')
      .where('expiresAt', '>', now).orderBy('expiresAt').limit(30).get(),
  ];
  for (let index = 0; index < friends.length; index += 30) {
    const chunk = friends.slice(index, index + 30);
    if (chunk.length === 0) continue;
    queries.push(
      db.collection('stories').where('ownerUid', 'in', chunk)
        .where('visibility', '==', 'friends')
        .where('expiresAt', '>', now).orderBy('expiresAt').limit(30).get(),
    );
  }
  const snapshots = await Promise.all(queries);
  const deduplicated = new Map<string, QueryDocumentSnapshot>();
  for (const snapshot of snapshots) {
    for (const story of snapshot.docs) {
      const ownerUid = story.get('ownerUid');
      if (ownerUid !== uid && !friends.includes(ownerUid) && story.get('visibility') !== 'public') continue;
      deduplicated.set(story.id, story);
    }
  }
  const stories = [...deduplicated.values()]
    .sort((a, b) => millis(b.get('createdAt')) - millis(a.get('createdAt')))
    .slice(0, 100)
    .map(serializeStory);
  return { stories };
});

export const deleteStory = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const storyId = textValue(input.storyId, 'معرّف الستوري', 128);
  await consumeRateLimit(uid, 'delete_story', 30, 60 * 60 * 1000);
  const ref = db.collection('stories').doc(storyId);
  const snapshot = await ref.get();
  if (!snapshot.exists || snapshot.get('ownerUid') !== uid) {
    throw new HttpsError('not-found', 'الستوري غير موجودة أو لا تملكها.');
  }
  await ref.delete();
  return { deleted: true };
});

export const createGroup = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const name = textValue(input.name, 'اسم المجموعة', 60);
  const description = typeof input.description === 'string'
    ? input.description.trim().slice(0, 280)
    : '';
  await consumeRateLimit(uid, 'create_group', 5, 24 * 60 * 60 * 1000);
  const profile = await requireProfile(uid);
  const groupRef = db.collection('groups').doc();
  const now = FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.create(groupRef, {
    name,
    description,
    ownerUid: uid,
    ownerName: typeof profile.displayName === 'string' ? profile.displayName : 'SALO user',
    isPublic: true,
    status: 'active',
    memberCount: 1,
    createdAt: now,
    updatedAt: now,
  });
  batch.create(groupRef.collection('members').doc(uid), {
    uid,
    role: 'owner',
    joinedAt: now,
  });
  await batch.commit();
  return { groupId: groupRef.id };
});

export const joinGroup = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const groupId = textValue(input.groupId, 'معرّف المجموعة', 128);
  await consumeRateLimit(uid, 'join_group', 30, 60 * 60 * 1000);
  const groupRef = db.collection('groups').doc(groupId);
  const memberRef = groupRef.collection('members').doc(uid);
  await db.runTransaction(async (transaction) => {
    const [group, member] = await Promise.all([
      transaction.get(groupRef),
      transaction.get(memberRef),
    ]);
    if (!group.exists || group.get('status') !== 'active' || group.get('isPublic') !== true) {
      throw new HttpsError('not-found', 'المجموعة غير متاحة.');
    }
    if (member.exists) return;
    const now = FieldValue.serverTimestamp();
    transaction.create(memberRef, { uid, role: 'member', joinedAt: now });
    transaction.update(groupRef, {
      memberCount: FieldValue.increment(1),
      updatedAt: now,
    });
  });
  return { joined: true };
});

export const saveUserSettings = onCall(CALLABLE_OPTIONS, async (request) => {
  enforcePayloadLimit(request);
  const { uid } = requireAuth(request);
  const input = dataObject(request.data);
  const settings = dataObject(input.settings);
  const allowed = new Set([
    'notifications', 'sound', 'messagePreview', 'readReceipts', 'onlineStatus',
    'darkMode', 'autoDownload', 'dataSaver', 'language',
  ]);
  for (const [key, value] of Object.entries(settings)) {
    if (!allowed.has(key)) {
      throw new HttpsError('invalid-argument', 'يتضمن الطلب إعداداً غير مسموح.');
    }
    if (key === 'language') {
      if (value !== 'العربية' && value !== 'English') {
        throw new HttpsError('invalid-argument', 'قيمة اللغة غير مسموحة.');
      }
    } else if (typeof value !== 'boolean') {
      throw new HttpsError('invalid-argument', `قيمة الإعداد ${key} غير صالحة.`);
    }
  }
  await consumeRateLimit(uid, 'save_settings', 30, 60 * 1000);
  await db.collection('userSettings').doc(uid).set({
    ...settings,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return { saved: true };
});
