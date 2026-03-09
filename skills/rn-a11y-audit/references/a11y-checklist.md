# Accessibility Audit Checklist

## Required Props by Element Type

### Interactive Elements (Buttons, Links, Switches)
- `accessibilityLabel` — **Critical.** Screen readers cannot describe unlabeled controls.
- `accessibilityRole` (or `role`) — **Critical.** Must be set to `button`, `link`, `switch`, `checkbox`, `radio`, etc.
- `accessibilityHint` — **Recommended** when the label alone does not convey what happens on activation.
- `accessibilityState` — Required for toggles (`checked`, `selected`, `disabled`, `expanded`).

### Images
- `accessibilityLabel` — **Critical** for informative images. Describe the content, not the file name.
- `accessibilityRole="image"` (or `role="img"`) — **Required.**
- Decorative images: set `accessible={false}` or `importantForAccessibility="no"` to hide from screen readers.

### Text Inputs
- `accessibilityLabel` — **Critical** if no visible label is adjacent.
- `accessibilityLabelledBy` (Android) — Reference a visible `<Text nativeID="...">` label.
- `accessibilityHint` — Recommended for non-obvious input formats.

### Headers / Section Titles
- `accessibilityRole="header"` (or `role="heading"`) — Enables VoiceOver rotor navigation by headings.

### Adjustable Controls (Sliders)
- `accessibilityRole="adjustable"` — **Required.**
- `accessibilityValue` — Must include `{ min, max, now }` or `{ text }`.
- `accessibilityActions` with `increment` / `decrement` — **Required** for VoiceOver swipe-up/down.

---

## Minimum Touch Target Sizes

| Platform | Minimum Size | Source |
|----------|-------------|--------|
| iOS | 44 x 44 points | Apple HIG |
| Android | 48 x 48 dp | Material Design Guidelines |

Elements smaller than these thresholds are difficult for users with motor impairments to activate. Use `hitSlop` or padding to expand the tappable area without changing visual layout.

---

## Valid `accessibilityRole` Values

`adjustable`, `alert`, `button`, `checkbox`, `combobox`, `header`, `image`, `imagebutton`, `keyboardkey`, `link`, `menu`, `menubar`, `menuitem`, `none`, `progressbar`, `radio`, `radiogroup`, `scrollbar`, `search`, `spinbutton`, `summary`, `switch`, `tab`, `tablist`, `text`, `timer`, `togglebutton`, `toolbar`, `grid`

### Valid `role` Values (takes precedence over `accessibilityRole`)

`alert`, `button`, `checkbox`, `combobox`, `grid`, `heading`, `img`, `link`, `list`, `listitem`, `menu`, `menubar`, `menuitem`, `none`, `presentation`, `progressbar`, `radio`, `radiogroup`, `scrollbar`, `searchbox`, `slider`, `spinbutton`, `summary`, `switch`, `tab`, `tabbar`, `tablist`, `text`, `timer`, `togglebutton`, `toolbar`

---

## Common Anti-Patterns

### 1. Icon-only buttons with no label
```tsx
// BAD — screen reader says "button"
<TouchableOpacity onPress={goBack}>
  <Icon name="arrow-left" />
</TouchableOpacity>

// GOOD
<TouchableOpacity
  onPress={goBack}
  accessibilityLabel="Go back"
  accessibilityRole="button">
  <Icon name="arrow-left" />
</TouchableOpacity>
```

### 2. Redundant labels that include the role
```tsx
// BAD — VoiceOver reads "Submit button, button"
<Pressable accessibilityLabel="Submit button" accessibilityRole="button">

// GOOD — VoiceOver reads "Submit, button"
<Pressable accessibilityLabel="Submit" accessibilityRole="button">
```

### 3. Images with filename labels
```tsx
// BAD
<Image accessibilityLabel="img_profile_2x.png" />

// GOOD
<Image accessibilityLabel="Profile photo of Jane Doe" accessibilityRole="image" />
```

### 4. Nested accessible elements
```tsx
// BAD — VoiceOver skips children inside an accessible parent
<View accessible={true}>
  <TouchableOpacity accessibilityLabel="Edit">...</TouchableOpacity>
  <TouchableOpacity accessibilityLabel="Delete">...</TouchableOpacity>
</View>

// GOOD — each button is independently focusable
<View>
  <TouchableOpacity accessibilityLabel="Edit" accessibilityRole="button">...</TouchableOpacity>
  <TouchableOpacity accessibilityLabel="Delete" accessibilityRole="button">...</TouchableOpacity>
</View>
```

### 5. Missing state announcements
```tsx
// BAD — toggle state not communicated
<Switch onChange={toggle} />

// GOOD
<Switch
  onChange={toggle}
  accessibilityRole="switch"
  accessibilityState={{ checked: isOn }}
  accessibilityLabel="Dark mode"
/>
```

### 6. Small touch targets
```tsx
// BAD — 24x24 is too small
<Pressable style={{ width: 24, height: 24 }} onPress={close}>
  <Icon name="close" size={24} />
</Pressable>

// GOOD — visual size stays 24, tappable area is 44x44
<Pressable
  style={{ width: 24, height: 24 }}
  hitSlop={10}
  onPress={close}
  accessibilityLabel="Close"
  accessibilityRole="button">
  <Icon name="close" size={24} />
</Pressable>
```

### 7. Dynamic content without live region
```tsx
// BAD — screen reader misses the update
<Text>{errorMessage}</Text>

// GOOD — announces changes automatically
<Text accessibilityLiveRegion="assertive" accessibilityRole="alert">
  {errorMessage}
</Text>
```
