# OrchardEye landing page

A self-contained marketing site for OrchardEye. No build step, no dependencies,
just plain HTML/CSS/JS. Structure inspired by clean agritech landers (hero → problem →
how-it-works → sensors → growers → rigor → pilot CTA), with OrchardEye's real content
and the same brand palette as the iOS app (`Color.brandLeaf` / amber / forest, defined in
[`../OrchardEye/OrchardEye/Views/Theme.swift`](../OrchardEye/OrchardEye/Views/Theme.swift)).

## Preview locally
```bash
cd web
python3 -m http.server 8000
# open http://localhost:8000
```

## Files
| File | Purpose |
|---|---|
| `index.html` | The single page (semantic sections, no framework). |
| `styles.css` | Design tokens + layout. Responsive, `prefers-reduced-motion` aware. |
| `main.js` | Scroll-reveal (IntersectionObserver) + sticky-nav shadow. Progressive enhancement, so content still shows with JS off. |
| `favicon.svg`, `og-image.svg` | Icon + social preview. |

## Deploy (Vercel)

The repo root includes `vercel.json` and `package.json` for Vercel. Import the repository in Vercel with the default root directory and deploy. Vercel runs:

```bash
npm run build
```

That copies this static site from `web/` into `dist/`, and Vercel serves `dist/`.

## Deploy (GitHub Pages)
Point Pages at this folder:
1. Repo **Settings → Pages → Build from a branch**.
2. Branch `main`, folder **`/web`** (or move these files to `/docs` if you prefer Pages' default).
3. Save. It publishes at `https://aranyoray.github.io/OrchardEye/`.

## Pilot form

The pilot section has a real signup form (name / email / orchard / message).
With no backend it composes a `mailto:` on submit, so it works on GitHub Pages.
To collect submissions online instead, set the form's `data-endpoint` (in
`index.html`) to a [Formspree](https://formspree.io) or Basin URL; `main.js`
POSTs there and falls back to mail on error. Update `data-mailto` to the real
inbox either way.

> Edit the pilot address and any copy before going live. "OrchardEye" is still a working name.
