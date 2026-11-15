PIXELDRIFT METRO - Godot 4 edition
EmacEArt - stylized pixel-art underground station kit

WHAT IS INSIDE
  334 models (.glb) sharing one 2048x2048 texture atlas
  382 ready-to-drop scenes under Prefabs/
  21 materials built on 4 atlas variants (clean, dirt, exodus, second set)
  5 playable scenes, from a single platform to a whole station

REQUIREMENTS
  Godot 4.4 or newer, Forward+ renderer.
  The project was built and verified in Godot 4.7.1.

HOW TO START
  1. Open the folder as a Godot project (project.godot is in the root).
  2. Let the editor finish the first import - it builds the mesh cache.
  3. Open Scenes/Demo.tscn. The camera is already framed;
     press F6 to see exactly what the store screenshots show.

THE FIVE SCENES
  Demo.tscn        the station of the store screenshots - platform, hall,
                   ticket gates, tunnels.  2162 meshes, 261 lights
  Demo2026.tscn    the same station lit for a night shoot, every ceiling tube
                   casting shadows.        2301 meshes, 407 lights
  Shooter.tscn     a corridor layout cut for first-person movement tests.
                   877 meshes, 169 lights
  Prolog.tscn      a small entrance hall with stairs - a level opening.
                   147 meshes, 22 lights
  Assets.tscn      every model in the pack laid out in rows, for picking.
                   362 meshes, 30 lights
  Each scene carries its own camera, so F6 opens on a framed shot.

HOW TO BUILD YOUR OWN STATION
  Drag any scene from Prefabs/ into your level. Every prefab is a plain
  Node3D with one MeshInstance3D, so it behaves like any other scene.
  Folder names follow the part of the station they belong to:
    Arch/        walls, columns, tunnel rings, staircases
    Ground/      platform slabs, tracks, stairs, work-site parts
    GroundDecor/ benches, crates, barrels, litter, ticket machines
    RoofDecor/   ceiling gates, pipes, neon lights
    TechRoom/    back-room furniture, books, cables, pallets
    WallDecor/   pipes, electric boxes, LCD boards, signs, labels
    Fence/, LCD/, Vehicle/  fences, screens, trolleys

MATERIALS
  Everything shares one atlas, so a whole station draws from a handful of
  materials. Swap Materials/Metro_new.tres for Metro_old.tres on a mesh to
  make a clean surface look worn; Metro_exodus.tres is the cold blue set.
  The emissive materials (Metro_clean_emiss_*, Metro2_emmision_*) drive the
  neon signs, EXIT boards and advert panels.
  All materials use nearest-neighbour filtering - that is what keeps the
  pixel texels crisp. Turn it off and the art turns to mush.

COLLISION
  Almost every model carries collision. Godot builds a StaticBody3D with a
  trimesh shape while it imports the .glb, so the shapes cost nothing in the
  download and you get a walkable station the moment the first import finishes.
  A few decorative pieces have none, exactly as in the original pack: the
  fluorescent tube, the book, the loose cable, the trolley and two wall fills.
  Single decorative instances inside the scenes have their shape switched off
  the same way - you walk through a wall column that was never solid.
  To change it for a model, open its .glb in the Import dock and set
  Generate Physics on the mesh node. To change one instance, select its
  CollisionShape3D in the scene and toggle Disabled.

LIGHTING IN THE DEMO SCENES
  No baking and no lightmaps, so you can move anything and the light follows.
  Ceiling tubes cast shadows and fade the shadow out past 30 m, which keeps
  the station above 80 fps at 1080p. Decorative lamps light without shadows -
  that is where the cost goes if you switch them all on.

  WorldEnvironment holds the tone mapping, ambient, glow, fog and SSAO; copy
  that node into your own scene to keep the look. Tone mapping is Filmic on
  purpose: ACES clips the red channel to zero under this saturated cyan light.

  The Vignette layer is a CanvasLayer with a ColorRect on top of the frame.
  Three parameters on its material - strength, radius and softness.
  Delete the layer if you do not want it.

SUPPORT
  emaceart@gmail.com
