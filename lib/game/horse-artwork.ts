export const isUniqueHorseArtwork = (url: string) => {
  const value = url.trim();
  return Boolean(value) && !value.split("?")[0].endsWith("/foundation-horse.png");
};

// The original Foundation image is an input/reference asset, never a visible
// fallback for an individual horse.
export const horseArtworkCandidates = (url: string) =>
  Array.from(new Set([url.trim()].filter(isUniqueHorseArtwork)));
