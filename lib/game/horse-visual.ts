export type VisualPhenotype = {
  breed:string;sex:string;age_years:number;color:string;body:string;coat:string;mane_tail:string;pattern:string;
  height_range?:string;height_hands?:number;movement?:string;temperament?:string;breed_constraints?:string;
  lighting?:string;
  face_marking:string;left_front:string;right_front:string;left_hind:string;right_hind:string;pose:string;view:string;background:string;
};

export function sexAnatomyConstraint(sex:string){return sex.toLowerCase()==="mare"
  ? "Sex/body type: female mare. Convey sex through the mare's overall body type only. Omit all visible genitalia and explicit reproductive anatomy."
  : "Sex/body type: stallion. Convey sex through the stallion's overall body type, neck, and muscling only. Omit all visible genitalia and explicit reproductive anatomy."}

export function formatHandHeight(value:number){const whole=Math.floor(value),inches=Math.round((value-whole)*10),total=whole*4+inches,hands=Math.floor(total/4),remainder=total%4;return `${hands}${remainder?`.${remainder}`:""}h`}

export function patternMaySubsumeMarkings(pattern:string,color=""){return /splashed white|tobiano|overo|tovero|sabino/i.test(`${pattern} ${color}`)}

export function coatAccuracyConstraint(color:string,coat="",maneTail=""){const value=color.toLowerCase();let base=value.includes("bay")?"BAY BASE IS MANDATORY: clearly brown/mahogany body pigment, NEVER orange, cinnamon, copper, or red; genetically jet-black mane, jet-black tail, black ear rims, and black lower-leg points wherever white patterning does not cover them. The brown body and black points must be visibly distinct. Any red/copper mane or tail, or a uniformly red body and legs, means chestnut/sorrel and is WRONG.":value.includes("chestnut")||value.includes("sorrel")?"CHESTNUT/SORREL BASE: red/copper body with red or flaxen mane and tail and absolutely no genetically black bay points.":value.includes("black")?"BLACK BASE: black body, mane, tail, ear rims, and lower legs; do not substitute dark bay or chestnut.":value.includes("palomino")?"PALOMINO BASE: gold body with cream/flaxen mane and tail and no black bay points.":"Render the named genetic base coat literally without substituting a visually similar color.";if(value.includes("splashed white"))base+=" SPLASHED WHITE PATTERN: bold irregular white rises upward from the legs and underside, often with a broad white face, while all remaining pigmented areas MUST retain the stated base-coat pigment. Pattern-created white may extend beyond separately listed leg or face markings.";return `${base} Database coat description: ${coat||color}. Database mane/tail description: ${maneTail||"coat-appropriate"}.`}

export function buildHorseImagePrompt(v:VisualPhenotype){return `Use case: polished game character illustration
Asset type: persistent Legacy Equine individual horse profile artwork
Primary request: Create a new, distinct, anatomically believable ${v.breed} ${v.sex.toLowerCase()} matching every structured visual trait below. Breed identity and the exact listed coat phenotype are strict requirements.
Age: ${v.age_years} years old, a young adult horse
${sexAnatomyConstraint(v.sex)}
Breed and body: ${v.body}
Breed height/proportion: ${v.height_range ?? "proportionate to the breed"}
Individual genetically expressed mature height: ${v.height_hands ? `${formatHandHeight(v.height_hands)} at the withers; make limb length, barrel depth, bone, and overall scale internally consistent with this exact height and breed` : "breed-appropriate mature height"}
Characteristic way of going: ${v.movement ?? "balanced natural movement"}
Breed character and expression: ${v.temperament ?? "alert natural expression"}
Registry-informed constraints and breed differentiation: ${v.breed_constraints ?? "avoid caricature and preserve functional conformation"}
Genetically calculated color/phenotype — MUST MATCH EXACTLY: ${v.color}
Coat appearance — MUST visually read as this listed color without substitution: ${v.coat}
Mane and tail: ${v.mane_tail}
Critical base-coat verification: ${coatAccuracyConstraint(v.color,v.coat,v.mane_tail)}
Genetic coat pattern: ${v.pattern}
Persistent facial marking: ${v.face_marking}
Persistent leg markings: left front ${v.left_front}; right front ${v.right_front}; left hind ${v.left_hind}; right hind ${v.right_hind}
Pose and view: ${v.pose}; ${v.view}
Scene/backdrop: none. Isolate the horse on a genuinely transparent alpha background with no room, floor, horizon, landscape, studio sweep, rectangle, colored field, or simulated gray-and-white transparency checkerboard.
Lighting and clarity: ${v.lighting ?? "bright neutral daylight, crisp coat detail, clean highlights, accurate coat color, strong natural contrast, and no color cast"}
Style/medium: polished semi-realistic Legacy Equine game illustration; slightly stylized/cartoon-clean edges are welcome when they improve breed, anatomy, marking, and color accuracy; retain believable conformation and natural coat detail
Composition/framing: landscape 4:3, full horse entirely visible, generous clear space around ears, nose, hooves, and tail
Constraints: anatomically correct horse with exactly one head, two proportionate ears, four complete legs, four correctly formed knees/hocks/fetlocks, and four separate realistic hooves; no extra, missing, fused, duplicated, floating, bent, or malformed body parts; natural spine, neck attachment, shoulder, barrel, pelvis, joints, and weight-bearing stance; OMIT ALL VISIBLE GENITALIA, sheath, penis, testicles, udder, vulva, and explicit reproductive anatomy for every sex; do not produce a generic all-purpose AI horse; do not default every breed to the same anatomy; preserve sound functional anatomy without caricature; transparent empty background only; the exact ${v.color} color and ${v.pattern} pattern must be unmistakable; markings must stay on the specified face and legs; no rider; no tack; no handler; no props. ABSOLUTELY NO SIGNATURE, NO WATERMARK, NO ARTIST MARK, NO TEXT, NO PSEUDO-TEXT, NO LETTERS, NO NUMBERS, NO LOGO, NO SYMBOLS, AND NO WRITING ANYWHERE IN THE IMAGE. The image may contain only the horse and the approved empty neutral/transparent background; exactly one horse.`}
