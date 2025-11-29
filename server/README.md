# Khu Liên Hợp TT - API Server

A minimal Express + MongoDB server for your sports complex app.

## Setup

1. Install Node.js 18+.
2. Copy `.env.example` to `.env` and adjust if needed.
3. Install deps, init schema and seed:

```powershell
npm install
npm run init:schema
npm run seed
npm run dev
```

API: <http://localhost:3000>

Alternatively, if you prefer `mongosh` directly:

```powershell
npm run init:schema:mongosh
```

## Endpoints

- GET `/api/health` -> `{ ok: true }`
- GET `/api/sports` -> list seeded sports
- POST `/api/bookings` -> create a booking (expects mongodb ObjectId strings and ISO dates)
- GET `/api/customers/:id/bookings` -> bookings by customer id

## Backfill lịch sử thanh toán

Nếu trước đây bạn đã đánh dấu hoá đơn là `paid` nhưng chưa có bản ghi trong collection `payments`, hãy chạy script sau để tạo payment giả lập cho những hoá đơn đó (giúp "Đã thu" và "Doanh thu" hiển thị đúng):

```powershell
cd server
node scripts/backfill_paid_invoices.mjs --dry-run   # xem trước sẽ chèn gì
node scripts/backfill_paid_invoices.mjs             # thực sự chèn payments
```

Thêm `--limit <n>` nếu bạn muốn xử lý thử một vài hoá đơn đầu tiên trước.
