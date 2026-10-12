# Cortina Rules

TangoDisplay detects cortinas automatically by inspecting the genre tag of each track in Music.app. You configure the detection rules in the **Cortina Rules** settings tab.

![Cortina Rules settings](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/cortina-rules.png)

---

## How detection works

There are two independent rules. Either rule can flag a track as a cortina.

### Cortina Genres (allowlist)

When the **Allowlist rule** toggle is on, a track is classified as a cortina if its genre exactly matches (or partially matches, if enabled) one of the genres in this list.

- Default entry: `Cortina`
- Use this if your cortinas are tagged with a specific genre in Music.app

### Dance Genres (denylist)

When the **Denylist rule** toggle is on, a track is classified as a cortina if its genre is **not** in the list of known dance genres.

- Default entries: `Vals`, `Milonga`, `Tango` — all with **Partial match** enabled
- **Partial match** means the genre only has to *contain* the entry, anywhere and with any separator: "Vals" matches "Tango Vals", "Vals Criollo", "Tango-Vals" and "Tango: Vals"; "Tango" matches "Argentine Tango" and "Tango Nuevo". Matching ignores case and accents.
- `Milongón` / `Milongon` always counts as `Milonga` (built-in alias, no entry needed)
- Tracks with an empty genre field are also treated as cortinas under this rule

### Both rules active

When both rules are enabled, a track is a cortina if **either** rule matches.

---

## Adding and removing genres

**To add a genre:**
1. Type the genre name in the input field at the bottom of the relevant section
2. Click **Add**

**To remove a genre:**
Click the bin icon to the right of the genre entry.

**Partial match** checkbox: when checked, the entry only has to appear somewhere in the genre tag (substring, case- and accent-insensitive) rather than matching it exactly.

When a tag contains several entries — `Tango Vals`, `Tango: Milonga` — the entry that appears **furthest right** wins. That one resolution is shared by everything that asks "which dance is this?": cortina detection, the per-genre scenes in Appearance, the display label below, and per-genre plugin rules.

---

## Display label override

Each denylist entry has an optional **display label** field. When filled in, the label is shown on the dancer screen instead of the raw genre tag.

This is useful when your library uses compound genre tags like `Tango: Vals` or `Tango: Milonga` for correct organisation, but you want a cleaner label — just `Vals` or `Milonga` — displayed to dancers. With **Partial match** on, `Tango: Vals` resolves to the `Vals` entry (the rightmost match), so its label is the one shown.

**Example:**

| Genre tag (in library) | Display label | Shown on screen |
|---|---|---|
| `Tango: Vals` | `Vals` | VALS |
| `Tango: Milonga` | `Milonga` | MILONGA |
| `Tango` | *(empty)* | TANGO |

- Leave the field empty to show the raw genre tag as-is
- The label applies in both the dance-track view and the cortina "Coming Up" preview
- Detection logic is unaffected — the label is purely cosmetic

---

## Notes

> When both rules are enabled, a track is a cortina if either rule matches.

> Empty genre fields are treated as cortinas under the denylist rule.

---

## Tips

- If cortinas in your library have no genre set, enable the denylist rule and ensure all your tango genres are listed — any untagged track will then be treated as a cortina.
- If you use a dedicated "Cortina" genre, the allowlist rule alone is sufficient.
- You can enable both for belt-and-braces detection.

---

## Auto-Fade with the Built-in Player

When using the **Built-in Player**, your cortina rules drive the fade controls in the Setlist view.

As you approach the end of a tanda, click one of the two fade buttons in the player controls:

**Fade & Stop** — fades the current track's volume to zero over the configured duration, then stops playback. Trigger it as the last tanda track plays out so dancers hear a smooth fade rather than an abrupt cut.

**Fade & Continue** — fades to zero, then after a brief pause automatically advances to the next track and restores volume. Use this for a seamless handoff into a cortina track.

TangoDisplay applies your cortina rules to every setlist track in real time, so the "Coming Up" preview on the dancer display updates correctly as soon as the cortina begins playing.

Configure the fade duration (1–15 seconds) in **Player › Cortina fade**.
