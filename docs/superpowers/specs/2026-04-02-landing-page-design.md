# CodeIsland Landing Page Design Spec

## Overview

A promotional landing page for CodeIsland — a macOS notch app for monitoring AI coding agents. Built with React + Tailwind + shadcn/ui + Motion + Lucide React.

**Visual direction:** Pixel Island — deep purple starry sky, green accents, ASCII art throughout, monospace typography. Retro-terminal aesthetic meets whimsical island theme.

**Target audience:** Open-source developers and individual Claude Code users.

**Core narrative:** CodeIsland as the best notch companion for Claude Code.

## Tech Stack

- **Vite + React + TypeScript**
- **Tailwind CSS v4**
- **shadcn/ui** — buttons, cards
- **Motion (framer-motion)** — animations, interactive demo
- **Lucide React** — supplementary icons

## Page Structure

### 1. Navigation Bar

- Fixed top, transparent with backdrop blur
- Left: cat emoji + "CODEISLAND" in monospace
- Right: Features / Demo / GitHub links + Download CTA button
- Smooth scroll to anchors

### 2. Hero Section

- Full viewport height
- Background: deep purple gradient (#0c0a1d → #1e1b4b → #312e81)
- Animated twinkling stars (CSS keyframes)
- Large ASCII art center: pixel cat on island with waves

```
     ✦  .  ·    ✦       ·   .
  .    ✦    .       .  ✦
          /\_/\
         ( o.o )  ♪
          > ^ <
    ~~~~/|   |\~~~~
~~~~~~~~(_| |_)~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~
```

- Title: `Code` (white) + `Island` (green #4ade80) in monospace
- Subtitle: "Your AI agents live in the notch."
- Secondary text: "Monitor, approve, and jump back — right from the MacBook notch."
- CTA: "Download for Free" (green solid) + "Star on GitHub" (outline)
- ASCII wave decoration at bottom

### 3. Interactive Notch Demo

- Background: subtle gradient transition from hero
- Centered mock notch component with 4 states, cycled by click or auto-play:
  1. **Collapsed** — ASCII cat face + project name + status + badge
  2. **Expanded** — Session list with colored dots, tool names, durations
  3. **Approval** — Code diff preview with approve/deny buttons
  4. **Jump** — Arrow animation showing jump-to-terminal
- Motion `AnimatePresence` for state transitions (slide + fade)
- Pill navigation below: Monitor / Approve / Ask / Jump (like vibeisland.app)
- Each pill click switches to corresponding state
- Auto-cycle every 4 seconds if not interacted with
- All notch UI rendered in monospace/ASCII style

### 4. Features Section (6 cards)

- Section title: "Features" in monospace
- 3x2 grid (responsive: 1 col mobile, 2 col tablet, 3 col desktop)
- Each card: dark bg with purple border, ASCII art icon + title + description
- Cards:
  1. **Pixel Cat** — cat ASCII + "6 animated states that react to your agents"
  2. **Zero Config** — lightning ASCII + "One launch, auto-installs hooks"
  3. **Notch Approval** — checkmark ASCII + "Approve with code diff preview"
  4. **Session Monitor** — terminal ASCII + "All agents at a glance"
  5. **cmux Jump** — arrow ASCII + "Jump to the exact terminal tab"
  6. **Sound Alerts** — bell ASCII + "8-bit synthesized notification sounds"
- Hover: subtle border glow (purple), slight scale with Motion

### 5. How It Works (3 steps)

- Horizontal timeline on desktop, vertical on mobile
- Three steps connected by dashed ASCII line:
  1. `brew install` — "Install with one command"
  2. `Launch` — "CodeIsland auto-configures Claude Code hooks"
  3. `Flow` — "Monitor and approve from the notch"
- Each step: number badge + ASCII illustration + description
- Motion: steps animate in sequentially on scroll (stagger)

### 6. Open Source Section

- Title: "Open Source & Free Forever"
- MIT license badge
- GitHub star count (static placeholder, can be dynamic later)
- Contributor avatars row (placeholder circles)
- CTA: "Fork & Contribute" + "Read the Docs"
- ASCII decoration: small island/flag

### 7. Footer

- Dark bg, minimal
- Left: CodeIsland logo + "MIT License"
- Center: GitHub / Twitter / Discord links
- Right: "Made with ♥ and Claude Code"
- ASCII wave top border

## Color Palette

| Token | Value | Usage |
|-------|-------|-------|
| bg-deep | #0c0a1d | Page background |
| bg-purple | #1e1b4b | Section backgrounds |
| purple-mid | #312e81 | Gradients |
| purple-accent | #6366f1 | Interactive elements |
| purple-light | #a5b4fc | Secondary text |
| purple-pale | #c4b5fd | Tertiary text |
| green | #4ade80 | Primary accent, CTA, status dots |
| green-dark | #16a34a | Green hover states |
| amber | #f59e0b | Warning/needs-attention status |
| text-primary | #f5f3ff | Headings |
| text-secondary | #e4e4e7 | Body text |
| text-muted | #71717a | Timestamps, labels |
| border | rgba(139,92,246,0.15) | Card borders |

## Typography

- **Headings:** `'Courier New', 'Fira Code', monospace`
- **Body:** System sans-serif via Tailwind defaults
- **ASCII art:** `'Courier New', monospace` — critical for alignment
- **Code:** Same monospace stack

## Animation Plan

- Stars: CSS `@keyframes twinkle` (opacity pulse, staggered delays)
- Hero ASCII cat: subtle float animation (translateY)
- Notch demo: Motion `AnimatePresence` with `layout` prop for smooth resizing
- Feature cards: Motion `whileInView` fade-up with stagger
- How it Works: Sequential reveal on scroll
- Smooth scroll behavior for nav links

## File Structure

```
codeisland-landing/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── index.css           # Tailwind directives + custom CSS
│   ├── components/
│   │   ├── Navbar.tsx
│   │   ├── Hero.tsx
│   │   ├── NotchDemo.tsx    # Interactive demo (biggest component)
│   │   ├── Features.tsx
│   │   ├── HowItWorks.tsx
│   │   ├── OpenSource.tsx
│   │   └── Footer.tsx
│   └── lib/
│       └── utils.ts         # cn() helper from shadcn
```

## Project Location

`~/Documents/AI/codeisland-landing/`

Separate from the main CodeIsland Swift project.
