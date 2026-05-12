---
name: Momentum & Flow
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#434655'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#784b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#996100'
  on-tertiary-container: '#ffeedd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Lexend
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Lexend
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Lexend
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Lexend
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Lexend
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Lexend
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
  gutter: 16px
  margin: 20px
---

## Brand & Style

The design system is built on a philosophy of "Optimistic Precision." It targets individuals seeking to improve their lives through small, consistent wins. The UI must feel like a supportive coach: organized, clear, and celebratory without being overwhelming.

The aesthetic follows a **Modern Minimalism with Glassmorphic accents**. By utilizing significant whitespace and soft, translucent layers, the interface maintains a lightweight feel that reduces cognitive load. The goal is to make habit completion feel frictionless and psychologically rewarding through subtle depth and high-quality motion.

## Colors

The palette is anchored by "Energetic Blue" to represent focus and "Success Green" for achievement. 

- **Primary (Energetic Blue):** Used for active states, primary actions, and progress indicators. It conveys reliability and momentum.
- **Secondary (Success Green):** Reserved exclusively for completion states, checkmarks, and positive growth trends.
- **Tertiary (Warm Amber):** Used sparingly for "streak" indicators or gentle reminders, providing a warm contrast to the cooler primary tones.
- **Neutrals (Soft Grays):** A cool-toned slate gray palette ensures the interface feels modern and professional, rather than stark. 
- **Functional Colors:** Use a soft red (#EF4444) only for critical alerts or "missed" habit logs, ensuring the tone remains encouraging rather than punitive.

## Typography

This design system utilizes **Lexend** across all levels. Originally designed to reduce visual stress and improve reading throughput, Lexend perfectly aligns with the "encouraging and legible" requirement.

- **Headlines:** Use Bold weights with tighter letter-spacing to create a sense of confidence and impact.
- **Body Text:** Use Regular weight with generous line-height to ensure the app feels airy and easy to scan.
- **Micro-copy:** Small labels should use the "Label-caps" style (All Caps + Bold) to provide clear hierarchy for metadata like dates or category tags.

## Layout & Spacing

The layout utilizes a **fluid grid system** with a strong emphasis on vertical rhythm based on an 8px square baseline. 

- **Containers:** Content is housed in centered containers with a maximum width of 600px for mobile-first focus, ensuring the user's eye stays on their daily tasks.
- **Padding:** Use "md" (24px) padding for primary card containers to give elements "room to breathe," reinforcing the lightweight aesthetic.
- **Grouping:** Use smaller "xs" and "sm" gaps to associate related items (like a habit name and its current streak count).

## Elevation & Depth

Hierarchy is achieved through **Tonal Layering and Soft Shadows**, avoiding heavy borders to keep the UI feeling "cloud-like."

- **Level 0 (Background):** The base layer is a very soft gray (#F8FAFC).
- **Level 1 (Cards):** Primary white surfaces with a "Long-Soft" shadow (Y: 4px, Blur: 20px, Color: 4% Black). 
- **Level 2 (Active/Floating):** Elements like "Add Habit" buttons or active modals use a more pronounced shadow with a hint of the primary color (Primary Blue at 10% opacity) to create a glowing, "lifting" effect.
- **Glassmorphism:** Apply a `backdrop-filter: blur(12px)` and semi-transparent white background (80% opacity) for sticky headers and navigation bars to maintain context of the content scrolling beneath.

## Shapes

The shape language is **Rounded and Friendly**. 

- **Standard Elements:** Use a 0.5rem (8px) radius for input fields and small buttons.
- **Primary Cards:** Use a 1rem (16px) radius to make the main content areas feel soft and approachable.
- **Interactive Pill Components:** Use "Full" rounding (Pill-shaped) for tags, chips, and progress bars to suggest fluid movement and growth.

## Components

- **Habit Cards:** The central component. It features a large checkbox on the left, habit title in `title-sm`, and a "mini-sparkline" or streak count on the right. Upon completion, the card background should transition from pure white to a 5% Success Green tint.
- **Primary Action Button:** A large, floating pill-shaped button using the Primary Color. Use an icon + label for clarity (e.g., "+" and "New Habit").
- **Progress Rings:** Use circular progress indicators with a thick stroke and rounded caps to visualize daily completion percentages.
- **Interactive Chips:** Small, pill-shaped filters (e.g., "Morning," "Health," "Work") that use a light-gray fill when inactive and a solid Primary Blue fill when selected.
- **Success Toasts:** Lightweight overlays that appear at the bottom of the screen when a habit is logged, featuring haptic-like animations and the Secondary Success Green.
- **Input Fields:** Borderless design with a light-gray background fill and 8px rounded corners. The label should float or sit clearly above the input area in `label-caps`.