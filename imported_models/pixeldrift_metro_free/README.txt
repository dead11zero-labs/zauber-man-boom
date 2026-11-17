PixelDrift Metro Free
Maciej EmacArt
================================================================

HOW TO ADD IT TO YOUR PROJECT
  Copy the contents of this pack into your Godot project (into res://).
  That is all -- the pack is self-contained and does not require any
  plugins or add-ons.

WHAT IS WHERE
  Prefabs/        ready-to-use object scenes (.scn) -- these are
                  what you instance in your own scenes
  Meshes/         source glTF files and the meshes extracted from
                  them (Meshes/extracted)
  Materials/      the five pack materials
  Textures/       diffuse texture variants and the ambient occlusion map
  Scenes/         showcase scene (FreeDemo.scn)
  Documentation/  this file, license, contents list

HOW TO USE
  Drag a .scn file from Prefabs/ into your scene, or use
  "Instantiate Child Scene". Every object already comes with its
  mesh and material.

CHANGING THE LOOK OF THE WHOLE PACK
  Every object is painted from one texture. The pack ships four diffuse
  variants in Textures/:
    PixelArt---EA01-Metro_Diff_clean.png    fresh, undamaged station
    PixelArt---EA01-Metro_Diff_dirt.png     worn and grimy
    PixelArt---EA01-Metro_Diff_exodus.png   abandoned, post-collapse
    PixelArt - EA01-Metro2_Diff.png         base set
  Point a material in Materials/ at a different one and every object
  using that material changes at once.

  The five materials cover the surface types in the pack: the standard
  metro surfaces (new and old), the exodus variant, porcelain tiling,
  and one alpha-blended material for grates, fences and cut-out details.

ART STYLE
  Pixel-art textures on low-poly meshes, built for first-person and VR
  projects. Textures are meant to stay unfiltered -- if your project
  changes the import filter to linear, the pixels will blur.

TESTED ON
  Godot 4.7.1

LICENSE
  Creative Commons Attribution 4.0 International License (CC BY 4.0)
  See LICENSE.txt in this folder.

CONTACT
  Website: emaceart.dev
  Discord: https://discord.com/invite/ctXaf5Ftqw

================================================================
