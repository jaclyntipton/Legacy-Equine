import { createClient } from "@supabase/supabase-js";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !service) return Response.json({ error: "Scheduler configuration unavailable" }, { status: 500 });
  const supabase = createClient(url, service, { auth: { persistSession: false } });
  const { data, error } = await supabase.rpc("process_due_news");
  if (error) return Response.json({ error: "Scheduled News processing failed" }, { status: 500, headers: { "Cache-Control": "no-store" } });
  return Response.json(data, { headers: { "Cache-Control": "no-store" } });
}
