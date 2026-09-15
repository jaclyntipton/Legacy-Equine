export const FOUNDATION_FALLBACK="/foundation-horse.png";
export const isUniqueHorseArtwork = (url: string) => {
  const value = url.trim();
  return Boolean(value) && !value.split("?")[0].endsWith("/foundation-horse.png");
};

// Correct anatomy outranks uniqueness. Missing or rejected system artwork uses
// the approved official Foundation image rather than a malformed generation.
export const horseArtworkCandidates = (url: string) =>
  Array.from(new Set([url.trim(),FOUNDATION_FALLBACK].filter(Boolean)));
