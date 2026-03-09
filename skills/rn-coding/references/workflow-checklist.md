# React Native Coding Workflow Checklist

Step-by-step checklist for writing React Native code. Referenced by rn-coding SKILL.md.

## Before You Code

- [ ] Identified all RN APIs and components needed
- [ ] Searched docs for each API (grep `refs/react-native-docs/docs/`)
- [ ] Read relevant doc files for props, usage patterns, caveats
- [ ] Noted platform differences (iOS vs Android behavior)
- [ ] Checked if any APIs are deprecated or have migration notes
- [ ] Identified required vs optional props for each component

## While Coding

- [ ] Using correct import paths (`react-native` vs platform-specific)
- [ ] Following patterns from official docs, not guessing at APIs
- [ ] Handling platform differences with `Platform.OS` or `Platform.select`
- [ ] Using proper TypeScript types for props and state (if TS project)
- [ ] Following project's existing patterns for navigation, state management, styling

## After Coding

- [ ] Suggest: `rn-layout-check` for visual verification
- [ ] Suggest: `rn-a11y-audit` for accessibility check
- [ ] Suggest: `rn-debug` for console error monitoring
- [ ] If errors: direct to `rn-diagnose`

## Common Gotchas

- FlatList requires `keyExtractor` or `key` prop on items
- ScrollView inside FlatList causes performance issues
- Absolute positioning works differently than web CSS
- StatusBar behavior differs iOS vs Android
- SafeAreaView only works on iOS (use `react-native-safe-area-context` for cross-platform)
- Dimensions API returns points not pixels on iOS (3x on Retina)
- TextInput `onChangeText` gives string, `onChange` gives event object
- TouchableOpacity vs Pressable: prefer Pressable (newer, more flexible)
