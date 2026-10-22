---
name: "image-prompt-builder"
description: "Build paste-ready Ideogram 4.5/4.0 image prompts (plain-language, JSON with layout and hex colors, or edit instructions) plus settings. Use whenever the user wants an image prompt or describes a picture, poster, ad or image edit."
---

# Image Prompt Builder

Turn a rough idea into a prompt Ideogram 4.5 will follow closely, and say which settings go with it. Ideogram 4.5 reads long, specific prompts faithfully (up to 10,000 characters), so the value you add is picking the right mode, putting details in the right order, and filling the gaps the user didn't think of. Decoration and hype words add nothing.

The plain-language structure below works for most image models. The JSON format and the edit pattern are Ideogram-specific. If the user names a different model, keep the structure and drop the Ideogram-only parts.

## 1. Pick the mode

| Situation | Mode |
| --- | --- |
| Photo, illustration, exploring ideas; exact placement doesn't matter | Plain language |
| Poster, ad, label, packaging, signage; several text blocks, fixed layout, brand hex colors, or one layout reused across images | JSON |
| The user has an existing image and wants something in it changed | Edit instruction |

When torn between plain and JSON, start plain. JSON is the tightening step once an output misses on layout or color.

## 2. Get the brief

Stop to ask only when a missing detail would make the prompt wrong rather than merely generic. That is usually:

- **The exact words** that must appear in the image. Don't invent copy the user will publish; use a clearly marked placeholder like `"[HEADLINE]"` if they haven't given it.
- **Where the image will run** (feed post, story, banner, print), since that decides the size and the composition.
- **For edits:** which object changes, and whether reference images or a mask are involved.

Ask at most two or three short questions at once. Fill in everything else (lighting, lens, props, palette) with sensible choices, and list those assumptions in one line so the user can push back.

## 3. Plain-language prompts

Write full sentences in this order. Words near the start carry more weight, so the main idea goes first. Skip any part the image doesn't need.

1. **Deliverable and summary.** What kind of image, what it's for, the main subject, the tone. Example opening: "Commercial product photograph for a 16:9 web banner: ..." Naming the format helps the model compose for the frame.
2. **Subject details.** Color, material, shape, texture. Exact text goes in double quotes, with its lettering style, weight, color and position.
3. **Pose or action.** Even a still object has one ("stands upright on a slate slab").
4. **Secondary elements.** Props that support the subject without competing with it.
5. **Setting and background.**
6. **Lighting and atmosphere.** Direction, quality, time of day, mood.
7. **Composition.** Camera angle, shot type, which third the subject sits in. If copy will be laid over the image later, say how much of the frame stays empty and what that space looks like ("the top 40% is a plain warm-white wall, left empty for a headline"). Without this, the model composes for the subject alone and leaves space wherever it happens to fall.
8. **Finish.** Lens, depth of field, brush texture, line quality, color grading.

Habits that matter:

- **Describe what is visible.** "Orange and pink light on the water" gives the model something to draw; "a beautiful scene" doesn't.
- **Say what you want, not what you don't.** Write "an empty street", not "a street with no people". Any noun you mention can end up in the image.
- **No weights or flags.** `::2`, `(word:1.3)`, `--ar 16:9` and `--style` are read as literal words. Aspect ratio, seed, image count and quality are settings (section 6).
- **Write the prompt in English.** English gives the most reliable results, especially with text in the image. Translate the user's description if needed, but keep their quoted copy exactly as given, accents included.
- **Keep it on one idea.** A long prompt is fine; a prompt that mixes unrelated ideas confuses the model.

## 4. JSON prompts

Ideogram 4.5 and 4.0 use the same JSON format. When pasted into Ideogram it must be raw JSON: no comments, no trailing commas. Showing it in a code block in chat is fine, since copying the block copies only the JSON.

```json
{
  "high_level_description": "One or two sentences that sum up the whole image.",
  "style_description": {
    "aesthetics": "mood and look",
    "lighting": "direction, quality, shadows",
    "medium": "photograph | illustration | 3D render | painting | graphic design",
    "art_style": "for non-photo work only",
    "color_palette": ["#RRGGBB"]
  },
  "compositional_deconstruction": {
    "background": "The setting behind everything.",
    "elements": [
      { "type": "text", "bbox": [100, 50, 250, 950], "text": "EXACT WORDS", "desc": "Typeface style, weight, color, alignment.", "color_palette": ["#RRGGBB"] },
      { "type": "obj", "bbox": [280, 150, 800, 850], "desc": "Detailed description of the object or subject." }
    ]
  }
}
```

Rules:

- **Top-level order:** `high_level_description` (required), `style_description` (optional), `compositional_deconstruction` (required). If a required key is missing, Ideogram reads the whole thing as plain text.
- **`photo` or `art_style`, never both.** Use `photo` (camera and lens, e.g. "85mm, f/1.8, shallow depth of field") for photographs and `art_style` for everything else.
- **Element key order:** for `obj` it is type, bbox, desc, color_palette; for `text` it is type, bbox, text, desc, color_palette. `bbox` and `color_palette` are optional.
- **Bounding boxes:** `[y_min, x_min, y_max, x_max]` on a 0–1000 scale, origin at the top left, vertical values first. Keep the lower value before the upper one on each axis. Make text boxes tall enough for their copy and check that boxes don't overlap unintentionally. Leave `bbox` out to let the model place the element.
- **Colors:** full six-digit hex. Up to 16 for the whole image, up to 5 per element. Include the background color to set the overall tone, and highlight and shadow colors to steer the lighting.
- **Text:** each block of text is its own element. `text` holds the exact words; `desc` holds the typography.
- **Element order:** most important first. Very long JSON can lose its last elements.
- **Magic Prompt off.** Otherwise it rewrites the hand-written JSON.

Before handing JSON over, check it parses (balanced braces, double quotes, no trailing commas) and that every bbox stays within 0–1000.

## 5. Edit instructions

Ideogram 4.5 is built for editing: untouched pixels are copied from the source, so repeated edits don't drift or pile up artifacts. Use this pattern:

**[Target] → [one concrete change] → [what stays] → [framing]**

> Replace the white mug on the desk with a matte black ceramic mug of the same size. Keep the laptop, the notebook, the window light and the shadows exactly the same. Keep the framing exactly the same.

- **One change per turn.** Split a bigger brief into a numbered sequence of turns, each run on the previous result. Single changes are easier to check and to undo.
- **The keep line matters.** It stops the change from spreading to nearby objects. "Keep the framing exactly the same" prevents re-cropping.
- **Text edits:** quote the new words exactly and ask for the same typeface, size and position. The same pattern works for translating a sign or label.
- **Reference images:** up to 4, or 3 when a mask is used. Give each one a single job and name it by number ("the terracotta fabric from image 3"). Numbering follows upload order; on some platforms the image being edited counts as image 1, so check.
- **Masks:** use one when the wording alone could hit the wrong object. Which color marks the editable area depends on the platform, so check its docs.
- **Restoration:** fix damage in stages and name what must stay exact (faces, pose, proportions).
- **Magic Prompt doesn't apply to edits.**

## 6. Settings to recommend

These go next to the prompt, never inside it.

| Setting | Recommendation |
| --- | --- |
| Magic Prompt | Off for a finished brief or hand-written JSON, since it adds details nobody asked for. Auto or On for a short idea the user wants expanded. |
| Size | Choose from where the image runs. 2K presets for delivery: 2048×2048 (1:1), 2560×1440 (16:9), 1440×2560 (9:16), 1792×2240 (4:5), 3072×1024 (3:1). 1K presets for drafts: 1024×1024, 1280×720, 720×1280, 896×1120. Name the format in the prompt too. |
| Quality | Low to check composition and wording, high for the final (high is the default). |
| Seed | Fix it while iterating, so differences come from the prompt. |

Ideogram 4.5 uses fixed size presets from 1K to 2K, from square up to 3:1 either way. Setting names differ by platform: `magic_prompt` in the Ideogram API, `settings.magicPrompt` on Runware, `prompt_enhance` on Leonardo. Use the name for the user's platform when you know it.

## 7. What to hand back

1. The mode, plus one line of assumptions.
2. The prompt in a code block, ready to paste.
3. The settings as a short list.
4. Two or three levers: the line to change for a different look, or for edits the next turn in the sequence.

Keep the commentary short. The prompt is the product.

## 8. When a result misses

Ask what's wrong, change one thing, and keep the seed.

| Problem | Fix |
| --- | --- |
| Subject ignored or underplayed | Move it earlier and describe it concretely |
| Unwanted object appears | Remove the word that invited it; describe that space positively |
| Text misspelled or misplaced | Shorten the copy, quote it near the start, give size and position; then switch to JSON with a bbox |
| Layout drifts | Switch to JSON with bounding boxes |
| Colors off | JSON palette, including the background color |
| Extra details nobody asked for | Turn Magic Prompt off |
| Edit spreads beyond the target | Add or extend the keep line, add a mask, split into single changes |

## Examples

**Plain language.** Request: "Instagram post for my bakery's new cinnamon rolls, text 'Fresh every Saturday'."

```
Food photograph for a 4:5 Instagram feed post: three glazed cinnamon rolls on a speckled stoneware plate, the icing dripping slightly down the sides. The text "Fresh every Saturday" appears in the top quarter in a warm brown hand-lettered script. A dusting of cinnamon and a folded linen napkin sit beside the plate on a worn oak table near a bright window. Soft morning light from the left, warm and cozy. The plate sits in the lower two thirds, shot from a 45-degree angle, and the top quarter is a plain cream wall with room for the lettering. 50mm lens, shallow depth of field, natural color.
```

Settings: 1792×2240, Magic Prompt off, quality low for drafts and high for the final.

**JSON.** Request: "Poster for our spring farmers market, Riverside Market, Saturdays 8–13, Old Mill Square, brand green #2F5D3A."

```json
{
  "high_level_description": "A cheerful illustrated poster for a spring farmers market called Riverside Market, held on Saturdays at Old Mill Square.",
  "style_description": {
    "aesthetics": "fresh, friendly, handmade",
    "lighting": "flat, bright, even",
    "medium": "graphic design",
    "art_style": "flat vector illustration with subtle risograph grain, rounded shapes, bold typography",
    "color_palette": ["#F4EBDD", "#2F5D3A", "#E8743B", "#F2C14E", "#1F2A24"]
  },
  "compositional_deconstruction": {
    "background": "Warm cream paper with a faint grain texture.",
    "elements": [
      { "type": "text", "bbox": [60, 80, 220, 920], "text": "RIVERSIDE MARKET", "desc": "Large bold rounded sans-serif headline in deep green, centered across the top.", "color_palette": ["#2F5D3A"] },
      { "type": "obj", "bbox": [250, 120, 720, 880], "desc": "A wooden crate overflowing with radishes, carrots, lettuce and strawberries, drawn in flat vector style with a few loose leaves around it." },
      { "type": "text", "bbox": [760, 150, 840, 850], "text": "Saturdays 8–13", "desc": "Medium-weight sans-serif in burnt orange, centered below the crate.", "color_palette": ["#E8743B"] },
      { "type": "text", "bbox": [860, 250, 920, 750], "text": "Old Mill Square", "desc": "Small all-caps sans-serif in near-black, centered near the bottom.", "color_palette": ["#1F2A24"] }
    ]
  }
}
```

Settings: 1440×2560 or another portrait preset, Magic Prompt off.

**Edit sequence.** Request: "Make my living room photo feel warmer: green sofa, a rug, evening light."

1. Replace the gray sofa with a deep green velvet sofa of the same size and shape. Keep the coffee table, the floor, the window and the framing exactly the same.
2. Add a woven wool rug in faded terracotta under the coffee table. Keep everything else exactly the same.
3. Change the daylight to warm early-evening light, with a lit floor lamp beside the sofa. Keep the furniture, the layout and the framing exactly the same.