export type VisualPhenotype = {
  breed:string;sex:string;age_years:number;color:string;body:string;coat:string;mane_tail:string;pattern:string;
  height_range?:string;movement?:string;temperament?:string;breed_constraints?:string;
  lighting?:string;
  face_marking:string;left_front:string;right_front:string;left_hind:string;right_hind:string;pose:string;view:string;background:string;
};

export function buildHorseImagePrompt(v:VisualPhenotype){return `Use case: photorealistic-natural
Asset type: persistent Legacy Equine individual horse profile artwork
Primary request: Create a new, distinct, realistic ${v.breed} ${v.sex.toLowerCase()} matching every structured visual trait below. Breed identity is the highest-priority visual requirement. The horse must be recognizable as a ${v.breed} from silhouette, head, neck, torso, limb length, bone, and muscling before coat color is considered.
Age: ${v.age_years} years old, a young adult horse
Breed and body: ${v.body}
Breed height/proportion: ${v.height_range ?? "proportionate to the breed"}
Characteristic way of going: ${v.movement ?? "balanced natural movement"}
Breed character and expression: ${v.temperament ?? "alert natural expression"}
Registry-informed constraints and breed differentiation: ${v.breed_constraints ?? "avoid caricature and preserve functional conformation"}
Genetically calculated color/phenotype: ${v.color}
Coat appearance: ${v.coat}
Mane and tail: ${v.mane_tail}
Genetic coat pattern: ${v.pattern}
Persistent facial marking: ${v.face_marking}
Persistent leg markings: left front ${v.left_front}; right front ${v.right_front}; left hind ${v.left_hind}; right hind ${v.right_hind}
Pose and view: ${v.pose}; ${v.view}
Scene/backdrop: ${v.background}
Lighting and clarity: ${v.lighting ?? "bright neutral daylight, crisp coat detail, clean highlights, accurate coat color, strong natural contrast, and no color cast"}
Style/medium: polished realistic digital equine portrait with natural coat texture and anatomically correct conformation
Composition/framing: landscape 4:3, full horse entirely visible, generous clear space around ears, nose, hooves, and tail
Constraints: do not produce a generic all-purpose AI horse; do not default every breed to the same warmblood or stock-horse anatomy; do not confuse this breed with the other Legacy Equine Foundation breeds (Arabian, Thoroughbred, Quarter Horse, Hanoverian, Appaloosa, Morgan, Rocky Mountain Horse, Tennessee Walking Horse); preserve sound functional anatomy without caricature; pure neutral white RGB 255 255 255 background only—no gray, beige, ivory, cream, lavender, color cast, vignette, muddy cast, gradient, visible horizon, or colored rectangle; markings must stay on the specified face and legs; no rider; no tack; no handler; no props; no text; no logo; no watermark; exactly one horse.`}
