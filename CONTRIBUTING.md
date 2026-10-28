# Contributing

- Keep it original: no assets, names or code from commercial games (see LEGAL.md).
- New mini-games: add `game/games/<id>.gd` extending `MiniGame` (or `RallyBase`), then register it in
  `game/autoload/game.gd`. Use `Build` for models and `Sfx` for sounds.
- Run the three headless tests in the README before opening a PR.
- Commits: author must be your own identity; no secrets or personal data in the repo.
