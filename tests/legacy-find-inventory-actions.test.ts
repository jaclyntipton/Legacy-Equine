import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const sql=readFileSync("supabase/migrations/202611160006_inventory_item_actions.sql","utf8"),ui=readFileSync("app/stable-inventory.tsx","utf8"),css=readFileSync("app/stable-inventory.module.css","utf8");
describe("Legacy Find inventory actions",()=>{
 it("soft-consumes supplies and records an auditable use action",()=>{expect(sql).toContain("function public.use_stable_supply");expect(sql).toContain("department='stable_supplies'");expect(sql).toContain("set consumed_at=now()");expect(sql).toContain("'used'")});
 it("allows owned unequipped inventory to be discarded without deleting history",()=>{expect(sql).toContain("function public.discard_inventory_item");expect(sql).toContain("stable_id=auth.uid()");expect(sql).toContain("Unequip this item before discarding it");expect(sql).toContain("Unlist this item before discarding it");expect(sql).not.toContain("delete from player_store_items")});
 it("exposes Use and confirmed Discard controls in inventory rooms",()=>{expect(ui).toContain("Use One");expect(ui).toContain("Discard One");expect(ui).toContain("window.confirm");expect(ui).toContain("discard_inventory_item");expect(ui).toContain("use_stable_supply")});
 it("keeps the RPCs authenticated and the action history player-scoped",()=>{expect(sql).toContain("enable row level security");expect(sql).toContain("stable_id=auth.uid()");expect(sql).toContain("grant execute on function public.use_stable_supply(uuid),public.discard_inventory_item(uuid)to authenticated")});
 it("presents inventory as responsive cards with distinct safe and destructive actions",()=>{expect(css).toContain(".itemActions");expect(css).toContain(".discardButton");expect(css).toContain("inventoryshelves article");expect(css).toContain("@media(max-width:760px)");expect(css).toContain(":focus-visible")});
 it("gives Feed Room a dedicated compact selection workflow",()=>{expect(css).toContain(":has(.horsePicker)");expect(css).toContain(".horseList");expect(css).toContain(".feedSummary");expect(css).toContain(".feedButton");expect(css).toContain("grid-template-columns:repeat(2,minmax(0,1fr))")});
});
