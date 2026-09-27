# Cookie dialogue

`DialogueManager` is an autoload. It loads `dialogues_structured.json` once and indexes its random pools. Both gameplay levels register their cookies through `dialogue_context.gd`; no player or level node paths are stored in the manager.

The existing `dialog_bubble.tscn` is reused, with a stretchable body and tail from `assets/Speechbubble Pack/Blank bubble.png`. It retains its 0.2-second pop-in, wraps text, follows the speaker, and clamps to the gameplay viewport. Bubble dimensions track camera zoom and world tiles. Bodies are capped at 2.75 tiles wide and 2.5 tiles high, with a small tail; shorter text reduces the height. Explicit text measurement prevents wrapped-label minimum sizes from inflating the panel. Long lines use a smaller font when necessary. Configure the caps with `[bubble] max_width_tiles` and `max_height_tiles` (hard limits keep the full bubble below three tiles). The gameplay footer remains separate.

## Calls

```gdscript
DialogueManager.request_bark("small_cookie", "idle")
DialogueManager.request_bark("big_cookie", "idle")
DialogueManager.request_bark("small_cookie", "blocked_by_obstacle")
DialogueManager.play_exchange("exchange_need_big_cookie")
DialogueManager.request_exchange("needs_big_cookie")
DialogueManager.play_story("conversation_01")
```

These return `true` if playback begins, or `false` if unavailable, blocked by priority/cooldowns, or no eligible content exists. New scene actors can register through `register_speaker("speaker_id", actor)`. References and bubbles are removed automatically on scene exit. `stop_dialogue()` cancels current playback.

Stories play only when explicitly requested. Space advances one story line; Enter skips a skippable story. These controls appear inside the bubble. Movement, switching, flipping, collisions, and puzzles continue normally.

## Automatic gameplay speech

Edit `dialogue_config.cfg` and restart the game to tune speech. The optional `DialogueContext` node now starts the first idle bark after 2–4 seconds, then waits 6–12 seconds between conversations. If a request is blocked, it retries after 1 second. Disable automatic speech with `[idle] enabled = false`. Interval countdowns pause during active conversations.

Existing gameplay signals request help when the small cookie struggles, obstacle barks on blocked flips, and success barks after catapult landings. Separation is sampled every 0.5 seconds: over 384 world pixels (6 tiles) triggers an exchange once, returning within 256 (4 tiles) resets the state, and another separation request requires a 25-second cooldown. The `[separation]` section controls these values and can disable detection. Rejected requests retry at the sampling interval; only successful playback latches the separation state. Context detection does not alter movement or puzzle logic.

## Content and scheduling

Add a context string to a line's `contexts` array under `random_dialogue.pools`, then call `request_bark(speaker_id, "new_context")` from the relevant puzzle. Exchanges use `contexts`, `weight`, and an ordered `sequence` of pool line IDs. All IDs should be unique.

Selection uses positive `weight` values. The `[random]` section in `dialogue_config.cfg` overrides the JSON defaults: a 3-second cooldown after conversations, a 30-second same-line cooldown, immediate-repeat prevention, and a 50% reply chance. Missing tuning keys retain the JSON defaults. A line can override `reply_chance`; only eligible opposite-speaker `reply_candidates` can reply, and replies do not recursively trigger more replies. Exchanges respect line eligibility and keep their internal ordering.

Priority is story > puzzle-critical > exchange > context bark > idle. `danger`, `near_hazard`, and `needs_big_cookie` are puzzle-critical. Higher priorities can preempt active lower priorities; idle never interrupts. Cooldowns apply to new gameplay conversations, not lines within one conversation. Repeated context calls do not queue up a backlog.

The `[bubble]` section controls text timing: 1.5 base seconds plus 0.055 seconds per character, clamped to 2.5–12 seconds, and a 0.35-second gap between lines. Voice playback can extend the duration. Audio paths in JSON are normalized to `res://`; missing files are silently text-only. No voice files were present during integration. Voice uses the existing Master bus via a non-positional AudioStreamPlayer. Dialogue timers, animations, and voice obey SceneTree pause; this project currently has no separate pause menu.

The story cast includes speakers without scene actors. They use the same bubble scene as a top-centred narration panel rather than being assigned to either playable cookie. Bubbles show speech without speaker-name headings; speaker IDs remain available in dialogue signals. Registering one of those speakers later automatically anchors its lines to that actor.

Each supplied line now has an `expression`: `neutral`, `happy`/`smile`, `thrilled`, `angry`, `surprised`, `worried`, or `skeptical`. Edit this field to tune the delivery. The speaker holds that mood until its line ends, including longer voice playback. Normal flips and eye slides temporarily use neutral movement eyes, then resume the speech mood. Catapult happiness and struggle animations retain priority. Ending, skipping, or interrupting a line clears its mood; replies affect only the new speaker.

Signals: `dialogue_started(id)`, `line_started(line)`, `line_finished(line)`, and `dialogue_finished(id, interrupted)`.

For exported builds, include `*.json,*.cfg` in the export preset's non-resource file filter so the source remains available to FileAccess.

## Checks

```sh
godot --headless --path . --script tests/dialogue_integration.gd
```

Covers both speakers, following and viewport placement, missing and longer audio, weighted selection, replies, cooldowns, repeat prevention, story/exchange order, priorities, skip behavior, pause, automatic Sample2 dialogue, and scene cleanup. Existing stacking, grid movement, car, and level round-trip checks also pass.

## Files

Created: `dialogue_manager.gd`, `dialogue_context.gd`, `dialogue_config.cfg`, this README, `tests/dialogue_integration.gd`, `tests/dialogue_config.gd`, and `tests/dialogue_bubble_size.gd`.

Modified: `project.godot` (autoload), `scenes/cookie_controls.gd` (level registration), and the existing `dialog_bubble.gd` / `dialog_bubble.tscn` (presentation). Dialogue content and speech-bubble source artwork are used as supplied.
