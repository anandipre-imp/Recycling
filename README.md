# Imperial Recycling — website

Static redesign of [imperialrecycling.co](https://www.imperialrecycling.co/) with a luxury corporate look
(ink + champagne gold + ivory, Cormorant Garamond / Manrope).

All company content and contact details are carried over unchanged from the original site.

## Pages
- `index.html` — Home (hero, who we are, products, process, values, locations, CTA)
- `who-we-are.html` — Story, journey, material streams, values, compliance notice
- `locations.html` — Panama (HQ), Costa Rica, Jamaica, Suriname
- `contact.html` — HQ details, office hours, enquiry form (opens the visitor's email app addressed to peeyush@imperialrecycling.co)

## Run locally
No build step. Open `index.html` in a browser, or serve the folder:

```
python3 -m http.server 8000
```

Deploy by uploading the whole folder to any static host (Netlify, Vercel, GitHub Pages, cPanel).

## Brand files
`brand/` holds the logo recreated as vectors from the company business card:
- `imperial-recycling-logo.svg` — iR mark + wordmark (transparent background)
- `imperial-recycling-brand-plate.svg` — logo, tagline and the ISRI / MRAI / BIR Gold Member strip
- `@6x.png` versions of both for documents and social media

The site uses the SVGs from `assets/img/`.

## Clip Matcher iPhone app
`GalleryMatcher/` holds a separate project: an iPhone app that analyzes the videos in your camera roll on-device,
groups the ones that go together and suggests short videos to make from them. See `GalleryMatcher/README.md`.
