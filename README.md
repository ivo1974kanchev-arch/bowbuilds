# bowbuilds

Build, tune, and perfect your compound bow setup. Configure your bow, run the paper tuning wizard, and save/share your builds — all in one place.

## Quick Start

1. **Clone & install**
   ```bash
   git clone https://github.com/your-org/bowbuilds.git
   cd bowbuilds
   npm install
   ```
2. **Configure environment**
   ```bash
   cp .env.example .env.local
   # Fill in Supabase, Stripe, and app values
   ```
3. **Initialize the database**
   ```bash
   # Paste schema.sql into the Supabase SQL editor and run it
   ```
4. **Run locally**
   ```bash
   npm run dev
   # App: http://localhost:3000
   ```

## Environment Variables

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase public anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (server only) |
| `NEXT_PUBLIC_APP_URL` | Public base URL of the app |
| `STRIPE_SECRET_KEY` | Stripe secret API key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe publishable key |
| `STRIPE_PRO_PRICE_ID` | Stripe Price ID for the Pro plan ($7/mo) |

## Pricing

| Plan | Price | Highlights |
|---|---|---|
| Free | $0/mo | 1 build, configurator, paper tuning wizard, shareable card |
| Pro | $7/mo | Unlimited builds, full tuning toolkit, build history & diff, priority support |

## Deploy Notes

- **Vercel**: Connect repo → add all env vars → deploy. API routes run as serverless functions automatically.
- **Supabase**: Create project → run `schema.sql` → enable Email auth → configure Storage bucket `build-assets`.
- **Stripe**: Create Pro product + recurring price → copy Price ID into `STRIPE_PRO_PRICE_ID` → register webhook endpoint `https://your-domain.com/api/webhooks/stripe`.
- Estimated hosting cost: ~$30/mo (Supabase Pro) + Vercel Hobby/Pro as needed.