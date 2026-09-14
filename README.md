# Legacy Equine

An original browser horse simulation: buy foundation stock, train horses, create thoughtful pairings, and build permanent pedigrees.

## Run locally

```bash
pnpm install
pnpm dev
```

The current preview persists its state in local storage. Use the LE Store to buy up to three foundation horses, train eligible horses, and breed a stallion to a mare. Run `pnpm test` and `pnpm build` before release.

## Production setup

Create a dedicated Supabase project, apply `supabase/migrations` in order, and populate `.env.local` from `.env.example`. Production game mutations must use trusted transactional RPCs; see `ARCHITECTURE.md`. Deploy the verified Next.js build to a dedicated Vercel project.
