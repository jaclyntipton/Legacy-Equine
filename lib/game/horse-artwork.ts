export const RETIRED_FOUNDATION_ARTWORK=`/${["foundation","horse.png"].join("-")}`;
export const GENERIC_HORSE_PLACEHOLDER="/generic-horse-placeholder.png";
export const isUniqueHorseArtwork = (url: string) => {
  const value = url.trim();
  return Boolean(value) && !value.split("?")[0].endsWith(RETIRED_FOUNDATION_ARTWORK);
};

// Approved or player-selected artwork remains first priority. The supplied generic
// horse is display-only and carries no breed, sex, color, marking, or genetic meaning.
export const horseArtworkCandidates = (url: string) =>
  isUniqueHorseArtwork(url)
    ? [url.trim(), GENERIC_HORSE_PLACEHOLDER]
    : [GENERIC_HORSE_PLACEHOLDER];
