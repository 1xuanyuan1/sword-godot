# Resource policy

The repository must never contain original or derived PAL game content.

Ignored local-only locations include:

- `Data/`, `data/`, `local_data/`: original resource files.
- `generated/`: images, audio, manifests and databases produced by the importer.
- `*.rpg`: original save files.

Tests committed to the repository use small synthetic byte arrays created for format edge cases. Integration tests that require original data run locally and report only structural results; they must not commit screenshots, converted audio, dialogue, hashes intended to identify unauthorized downloads, or other derived content.

