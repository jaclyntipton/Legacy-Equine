export type Sex = "Mare" | "Stallion";
export type HorseOrigin = "Foundation" | "Bred" | "Admin Custom";
export type Stats = Record<string, number>;
export interface Horse {
  id: string; name: string; breed: string; sex: Sex; color: string; origin: HorseOrigin;
  birthDate: string; createdAt: string; sireId: string | null; damId: string | null;
  generation: number; birthStats: Stats; stats: Stats; tackBonuses: Stats; biography: string; imageUrl: string;
  studFee: number; lastBredAt: string | null; lastTrainedAt: string | null; retired: boolean;
}
export interface StableState { stableNumber: number; stableName: string; established: number; balance: number; purchases: number; horses: Horse[]; ledger: { id: string; amount: number; reason: string; at: string }[]; trainingLog: { horseId: string; stat: string; gain: number; at: string }[]; }
