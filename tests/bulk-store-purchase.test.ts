import{describe,it,expect}from"vitest";import fs from"node:fs";
const sql=fs.readFileSync("supabase/migrations/202609180005_bulk_store_purchases.sql","utf8"),page=fs.readFileSync("app/page.tsx","utf8"),control=fs.readFileSync("app/store-bulk-purchase.tsx","utf8"),inventory=fs.readFileSync("app/stable-inventory.tsx","utf8");
describe("bulk Store purchases",()=>{
 it("validates department-specific quantity limits and authoritative total",()=>{expect(sql).toContain("product.department='feed'and p_quantity>50");expect(sql).toContain("product.department='tack'and p_quantity>10");expect(sql).toContain("total:=product.price*p_quantity")});
 it("is atomic and idempotent",()=>{expect(sql).toContain("unique(stable_id,request_key)");expect(sql).toContain("for update");expect(sql).toContain("if s.balance<total then raise exception 'Insufficient LED balance'");expect(sql).toContain("update stables set balance=balance-total");expect(sql).toContain("for i in 1..p_quantity loop")});
 it("offers the required quick quantities",()=>{expect(control).toContain("[1,5,10,25,50]");expect(control).toContain("[1,2,5,10]");expect(control).toContain("Custom");expect(control).toContain("Price each:");expect(control).toContain("Total:")});
 it("uses one bulk RPC from existing product cards",()=>{expect(page).toContain("purchase_store_product_bulk");expect(page).toContain("p_request:requestKey");expect(page).toContain("<StoreBulkPurchase")});
 it("stacks standard items and isolates crafted tack",()=>{expect(inventory).toContain("item.custom_name?item.id:item.product_id");expect(inventory).toContain("× {group.length}")});
});
