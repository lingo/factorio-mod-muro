# muro
Draw walls as lines or rectangles, place ghosts

## Tests

The regression tests use mocked Factorio runtime objects, so they can run
without launching the game. From the mod directory, run:

```sh
texlua tests/test_muro_wall_builder.lua
```

Any standard Lua interpreter can be used instead:

```sh
lua tests/test_muro_wall_builder.lua
```

The suite covers wall geometry, collision-layer filtering, natural obstacle
handling, modded buildings, deconstruction deduplication, and the separation
between building and reverse/deconstruction selection.
