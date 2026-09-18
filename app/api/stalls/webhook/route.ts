export const runtime="nodejs";
export async function POST(){return Response.json({error:"Payment provider webhooks are not enabled."},{status:503})}
