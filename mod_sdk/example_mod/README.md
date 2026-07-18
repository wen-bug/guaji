# Example Mod

From the game repository root:

`godot --headless --path . -s mod_sdk/example_mod/build_mod.gd -- example_mod.pck`

Move the generated package to the game's user Mod directory, enable it in the Mod manager, approve its code, and restart. The package demonstrates a skill, skill book, appearance, conditional dialogue, custom effect, AI condition, actor state, storage, RNG-compatible lifecycle, and save migration.

The files ending in `.gd.txt` and `.tscn.txt` are package templates. The build script removes the final `.txt` suffix, so the PCK contains normal `.gd` and `.tscn` paths without making Godot import the SDK example as part of the base game.
