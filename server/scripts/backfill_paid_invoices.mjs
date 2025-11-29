import dotenv from 'dotenv';
import { MongoClient, ObjectId } from 'mongodb';

dotenv.config();

const uri = process.env.MONGODB_URI;
if (!uri) {
  throw new Error('Missing MONGODB_URI in environment variables.');
}

const dbName = process.env.MONGODB_DB_NAME || 'khu_lien_hop_tt';
const DRY_RUN = process.argv.includes('--dry-run');
const LIMIT_ARG_INDEX = process.argv.findIndex((arg) => arg === '--limit');
const limit = LIMIT_ARG_INDEX > -1 ? Number.parseInt(process.argv[LIMIT_ARG_INDEX + 1], 10) : null;

const client = new MongoClient(uri);

/**
 * Normalize money values to a positive finite number.
 */
function normalizeAmount(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.max(0, value);
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) return Math.max(0, parsed);
  }
  if (value && typeof value.valueOf === 'function') {
    const converted = value.valueOf();
    if (typeof converted === 'number' && Number.isFinite(converted)) return Math.max(0, converted);
  }
  return 0;
}

async function main() {
  await client.connect();
  const db = client.db(dbName);
  console.log(`[backfill] Connected to ${dbName}`);

  const pipeline = [
    { $match: { status: { $in: ['paid'] } } },
    {
      $lookup: {
        from: 'payments',
        localField: '_id',
        foreignField: 'invoiceId',
        as: 'payments',
      },
    },
    { $match: { payments: { $size: 0 } } },
    { $project: { payments: 0 } },
  ];

  if (Number.isFinite(limit) && limit > 0) {
    pipeline.push({ $limit: limit });
  }

  const invoices = await db.collection('invoices').aggregate(pipeline).toArray();
  console.log(`[backfill] Found ${invoices.length} invoices without payments`);

  if (!invoices.length) {
    await client.close();
    console.log('[backfill] Nothing to do.');
    return;
  }

  const paymentsColl = db.collection('payments');
  const now = new Date();
  let inserted = 0;

  for (const invoice of invoices) {
    const amount = normalizeAmount(invoice.amount);
    if (amount <= 0) {
      console.warn(`[backfill] Skip invoice ${invoice._id} because amount is ${amount}`);
      continue;
    }

    const paymentDoc = {
      invoiceId: invoice._id instanceof ObjectId ? invoice._id : new ObjectId(String(invoice._id)),
      provider: 'legacy-backfill',
      method: 'manual',
      amount,
      currency: typeof invoice.currency === 'string' && invoice.currency.trim().length
        ? invoice.currency.trim()
        : 'VND',
      status: 'succeeded',
      createdAt: now,
      processedAt: now,
      meta: {
        source: 'backfill-script',
        note: 'Auto payment to align historical invoices',
      },
    };

    if (DRY_RUN) {
      console.log('[dry-run]', paymentDoc);
      inserted += 1;
      continue;
    }

    await paymentsColl.insertOne(paymentDoc);
    inserted += 1;
    console.log(`[backfill] Added payment for invoice ${invoice._id}`);
  }

  console.log(`[backfill] ${DRY_RUN ? 'Previewed' : 'Inserted'} ${inserted} payment(s).`);
  await client.close();
}

main().catch((err) => {
  console.error('[backfill] Failed:', err);
  client.close().catch(() => {});
  process.exit(1);
});
