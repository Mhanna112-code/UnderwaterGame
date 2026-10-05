# Mermaid-Weirdo isolated import inspection — October 5

Historical inspection/local-stage report. The laboratory-only role was
subsequently delivered in runtime6b8ea07/exportc98490b with actual hosted lab
fight acceptance. See [batch delivery](main-goals-ending-batch-oct5.md).
Final texture/color approval and the deferred opening remain outside this claim.

Delivered source `/Users/tomriddle1/Dropbox/Freak_Mermaid-Weirdo.fbx`, 30MB,
SHA256 `7d0606ec980cddfdd7e686bedf709a45370c92e73643215bfe6c324b7efc7014`.
Current Mermaid_Freak SHA256
`9d27e8646820ab7486ae01e2e256e92ad5a5dbe55371933f4bc0c6e57c5686ba`.

Both imported through Godot4.7.1 native FBX in a separate temporary project;
no existing asset was replaced. Reports and rendered views are in
`evidence/mermaid-weirdo-oct5`.

- Exactly the same ordered311 bone names. All179 animation tracks per clip.
- All17 old clips exist in the delivered variant;19 total, with only two
  extra0.001-second Plane actions (not new playable attacks).
- Same swimming/start/end, idle, hit, death and six attack names/timings.
- Current bounds2.001×3.999×1.153m; variant2.000×3.888×1.080m.
- One skinned mesh/two surfaces each; currentFemaleBase versus deliveredTethys3.
- Neither isolated import exposes embedded albedo textures. This does not prove
  the artist's separately delivered textures are absent or unusable. The current
  Tethys adapter uses an explicit red material fallback, not external texture
  bindings; any later texture application requires its own UV/presentation check.
- Front(+Z)/back and poison/swim sampled poses render in the delivered rig.
  Neutral gray inspection override makes shape visible; those images are not
  evidence of delivered textured color and must not replace game materials.

## Selected and locally implemented role

Existing laboratory Tethys presentation only, not a new compulsory boss, Cordys
substitute or grunt. `Battle` selects this model only for `lab_boss`, through the
same Tethys adapter. Original Mermaid_Freak/reference actor remains untouched;
no move/stat/XP/encounter/room/camera change. Existing explicit red material
fallback is retained. This does NOT claim delivered textures were imported or
that final artistic color has been approved. Opening identity/intro remains
unchanged and review-gated last.

Native role baseline rendered the old FemaleBase mesh/17 takes and failed five
variant assertions. After wiring: real laboratory Battle renders Tethys3;
13 distinct character motions deform its311-bone skinned rig, all78 motion-pair
checks pass, six attacks are production-called and facing remains +Z. Six base/
helper takes are excluded (the two extra Plane actions are not attacks).
Original reference actor still passes its13+4 classification and all motions.
Actual12-action lab victory reaches the computer/controller payoff, dismisses
and cold-loads without replay/reward duplication. Rendered production scene
passes1280×720 and720×480 containment, floor, silhouette and readable-actor
checks; screenshots inspected, native Metal on AppleM1.

Evidence: `evidence/mermaid-weirdo-oct5/laboratory`. Initial animation observer
timeouts were a harness defect: the first randomly encountered QTE lesson waits
for Enter. The observer now uses a reproducible seed and actual Enter input to
read that lesson, not a skipped attack or production flag mutation. A transient
test indentation error was repaired before rendering acceptance; neither was
counted as a production model bug. All final native commands exit0 without
script/engine errors. Exported browser lab presentation and matching hosted
delivery still remain; this local source is not yet on main/canonical.
