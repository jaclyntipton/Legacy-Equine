export const runtime="nodejs";
export async function POST(){return Response.json({error:"Live commerce is not enabled. No payment information was collected."},{status:503})}
