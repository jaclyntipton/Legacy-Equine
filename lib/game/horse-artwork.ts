export const RETIRED_FOUNDATION_ARTWORK=`/${["foundation","horse.png"].join("-")}`;
export const isUniqueHorseArtwork = (url: string) => {
  const value = url.trim();
  return Boolean(value) && !value.split("?")[0].endsWith(RETIRED_FOUNDATION_ARTWORK);
};

// Incomplete deterministic visuals intentionally render a branded non-illustrative
// pending state. Genetically incorrect fallback horses are never substituted.
export const horseArtworkCandidates = (url: string) =>
  isUniqueHorseArtwork(url) ? [url.trim()] : [];
