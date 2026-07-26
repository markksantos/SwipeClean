// Which capture gets which caption, and the brand the frames are drawn in.
// Rendered by ../../_pipeline/marketing/scripts/render.mjs.
//
// SwipeClean is iPhone-only (TARGETED_DEVICE_FAMILY "1"), so there is no iPad
// screenshot set to deliver.

export default {
  appName: 'SwipeClean',
  tagline: 'Tinder for your camera roll. Swipe left to clean, right to keep — nothing is deleted until you confirm.',
  icon: 'icon.png',

  // Lifted from the app icon's own gradient (sampled #4756CD -> #332680) and the
  // system accent the UI actually draws with, not eyeballed from a screenshot.
  brand: {
    bgHi: '#f8f9fd',
    bg: '#edeff8',
    bgLo: '#dcdff1',
    ink: '#14172b',
    inkSoft: '#5a6079',
    accent: '#4756CD',
    bezel: ['#3a4160', '#1e2440', '#333a58'],
    font: 'Inter',
  },

  phoneShots: [
    {
      out: '01-swipe.png',
      shot: 'shots/02-swipe.png',
      chip: 'One pass',
      headline: 'Swipe left to {clean},\nright to keep',
      sub: 'A real deck with momentum and haptics. Undo any decision, any time.',
    },
    {
      out: '02-similar.png',
      shot: 'shots/03-similar.png',
      chip: 'Similar photos',
      headline: 'Four near-identical shots.\n{Keep the best one.}',
      sub: 'Bursts grouped side by side and scored, so the keeper is obvious.',
    },
    {
      out: '03-home.png',
      shot: 'shots/01-home.png',
      chip: 'Smart albums',
      headline: 'Start wherever it\n{actually hurts}',
      sub: 'Screenshots, videos, selfies, or any single month of your library.',
    },
    {
      out: '04-storage.png',
      shot: 'shots/05-storage.png',
      chip: 'Storage',
      headline: 'See exactly\n{where it went}',
      sub: 'Every photo, video, and screenshot measured before you delete a thing.',
    },
    {
      out: '05-supercut.png',
      shot: 'shots/04-supercut.png',
      chip: 'Supercut',
      headline: 'Turn a month into\na {montage}',
      sub: 'Pick a song and SwipeClean cuts the good frames to the beat.',
    },
    {
      out: '06-achievements.png',
      shot: 'shots/06-achievements.png',
      chip: 'Streaks',
      headline: 'Small habit,\n{gigabytes back}',
      sub: 'Daily streaks and twelve milestones, from your first hundred to five thousand.',
    },
  ],

  // App preview beats.
  //
  // The two swipe beats are real screen recordings, not stills: Apple requires an
  // App Preview to be captured from the app in use, and for an app whose pitch is
  // a gesture, a slideshow undersells it. Recorded with
  // ../../_pipeline/record.sh driving SwipeCleanUITests/DemoFootageUITests.
  //
  // Total runs ~17s, inside Apple's 15-30s window for an App Preview.
  beats: [
    {
      clip: 'clips/swipe-demo.mp4',
      startFrom: 0.4,
      caption: 'Left to clean, right to keep',
      seconds: 3.8,
    },
    {
      clip: 'clips/swipe-demo.mp4',
      startFrom: 8.6,
      caption: 'Undo anything, any time',
      seconds: 3.4,
    },
    { shot: 'shots/03-similar.png', caption: 'Near-duplicates, grouped and scored', seconds: 3.4 },
    { shot: 'shots/05-storage.png', caption: 'Watch the space come back', seconds: 3.2 },
    { shot: 'shots/04-supercut.png', caption: 'Make a montage of what you kept', seconds: 3.4 },
  ],
};
