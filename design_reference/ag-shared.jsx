// ag-shared.jsx — Agreeo design system: tokens, data, icons, shared components
// Cinema-dark theme · coral-red + electric purple accents
// Exports everything to window for cross-file use.

// ───────────────────────── Tokens ─────────────────────────
const T = {
  bg: '#0E0C12',
  bg2: '#14111B',
  surface: '#1B1825',
  surface2: '#241F31',
  line: 'rgba(255,255,255,0.075)',
  line2: 'rgba(255,255,255,0.14)',
  text: '#F6F3F0',
  sub: 'rgba(246,243,240,0.60)',
  faint: 'rgba(246,243,240,0.38)',
  red: '#FF5D54',
  redDeep: '#E03A4E',
  purple: '#8B6CFF',
  purpleDeep: '#6B45F0',
  gold: '#FFC24B',
  green: '#46D4A0',
  onText: '#1a0e10',
  glass: 'rgba(30,26,40,0.78)',
  heroBg: '#0E0C12',
  grad: 'linear-gradient(135deg, #FF6A5C 0%, #8B6CFF 100%)',
  gradSoft: 'linear-gradient(135deg, rgba(255,106,92,0.16) 0%, rgba(139,108,255,0.16) 100%)',
  disp: "'Bricolage Grotesque', system-ui, sans-serif",
  ui: "'Manrope', system-ui, sans-serif"
};

// ───────────────────────── Movie data ─────────────────────────
// Real well-known titles; posters are original styled placeholders.
const MOVIES = [
{ id: 'dune2', t: 'Dune: Part Two', y: 2024, m: 166, g: ['Sci-Fi', 'Adventure'], r: 8.5, c1: '#C8843D', c2: '#5B2E12', mood: 'desert', d: 'Paul Atreides unites with the Fremen to wage war against House Harkonnen and seize his destiny across the dunes of Arrakis.' },
{ id: 'oppen', t: 'Oppenheimer', y: 2023, m: 180, g: ['Drama', 'History'], r: 8.3, c1: '#D9613A', c2: '#1A1212', mood: 'fire', d: 'The story of J. Robert Oppenheimer and the race to build the atomic bomb that would change the world forever.' },
{ id: 'para', t: 'Parasite', y: 2019, m: 132, g: ['Thriller', 'Drama'], r: 8.5, c1: '#3E7D5A', c2: '#10130F', mood: 'grass', d: 'A poor family schemes to become employed by a wealthy household, until a twist of fate upends everyone\u2019s plans.' },
{ id: 'eeaao', t: 'Everything Everywhere All at Once', y: 2022, m: 139, g: ['Sci-Fi', 'Comedy'], r: 7.8, c1: '#E0518F', c2: '#2B1A55', mood: 'multiverse', d: 'A laundromat owner is swept into a multiverse adventure where she alone can save existence.' },
{ id: 'lala', t: 'La La Land', y: 2016, m: 128, g: ['Romance', 'Musical'], r: 8.0, c1: '#5C63C4', c2: '#1A1430', mood: 'dusk', d: 'A jazz pianist and an aspiring actress fall in love while chasing their dreams in Los Angeles.' },
{ id: 'inter', t: 'Interstellar', y: 2014, m: 169, g: ['Sci-Fi', 'Drama'], r: 8.7, c1: '#3C6B9E', c2: '#0C1018', mood: 'space', d: 'A team of explorers travels through a wormhole in search of a new home for humanity.' },
{ id: 'whip', t: 'Whiplash', y: 2014, m: 107, g: ['Drama', 'Music'], r: 8.5, c1: '#C8952E', c2: '#161009', mood: 'jazz', d: 'A young drummer enrolls at a cutthroat conservatory under a ruthless instructor who will stop at nothing.' },
{ id: 'spirit', t: 'Spirited Away', y: 2001, m: 125, g: ['Animation', 'Fantasy'], r: 8.6, c1: '#C44A55', c2: '#15302E', mood: 'spirit', d: 'A girl wanders into a world of spirits and must find the courage to free her parents and herself.' },
{ id: 'knives', t: 'Knives Out', y: 2019, m: 130, g: ['Mystery', 'Comedy'], r: 7.9, c1: '#9A3742', c2: '#1C140E', mood: 'manor', d: 'A detective investigates the death of a patriarch among his eccentric, bickering family.' },
{ id: 'br2049', t: 'Blade Runner 2049', y: 2017, m: 164, g: ['Sci-Fi', 'Thriller'], r: 8.0, c1: '#C97A35', c2: '#10171C', mood: 'neon', d: 'A young blade runner uncovers a secret that could plunge what\u2019s left of society into chaos.' },
{ id: 'gbh', t: 'The Grand Budapest Hotel', y: 2014, m: 99, g: ['Comedy', 'Drama'], r: 8.1, c1: '#D98BA6', c2: '#5A3A6B', mood: 'pastel', d: 'A legendary concierge and his protégé become entangled in the theft of a priceless painting.' },
{ id: 'getout', t: 'Get Out', y: 2017, m: 104, g: ['Horror', 'Thriller'], r: 7.7, c1: '#B33A33', c2: '#120D0D', mood: 'dread', d: 'A young man uncovers a disturbing secret when he visits his girlfriend\u2019s family estate.' },
{ id: 'past', t: 'Past Lives', y: 2023, m: 105, g: ['Romance', 'Drama'], r: 7.8, c1: '#4E6FA8', c2: '#241A26', mood: 'blue', d: 'Two childhood friends reunite decades later for one fateful week that reframes their lives.' },
{ id: 'arriv', t: 'Arrival', y: 2016, m: 116, g: ['Sci-Fi', 'Drama'], r: 7.9, c1: '#5A7D72', c2: '#101513', mood: 'fog', d: 'A linguist races to communicate with mysterious visitors before global tensions ignite.' },
{ id: 'madmax', t: 'Mad Max: Fury Road', y: 2015, m: 120, g: ['Action', 'Adventure'], r: 8.1, c1: '#D06B2C', c2: '#143040', mood: 'wasteland', d: 'On the fringes of a wasteland, a woman rebels against a tyrant with the help of a drifter.' },
{ id: 'portrait', t: 'Portrait of a Lady on Fire', y: 2019, m: 122, g: ['Romance', 'Drama'], r: 8.1, c1: '#3E7E84', c2: '#3A1A12', mood: 'ember', d: 'On a remote isle, a painter and her subject fall into a fleeting, incandescent romance.' }];

const byId = (id) => MOVIES.find((m) => m.id === id);
const runtime = (m) => `${Math.floor(m / 60)}h ${m % 60}m`;
const ALL_GENRES = ['Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 'Drama', 'Fantasy', 'History', 'Horror', 'Music', 'Musical', 'Mystery', 'Romance', 'Sci-Fi', 'Thriller', 'Documentary'];

// Real film posters (TMDB image CDN). If one fails to load, Poster falls back
// to the styled gradient placeholder, so the UI never looks broken.
const TMDB = 'https://image.tmdb.org/t/p/w500';
const POSTER_PATHS = {
  dune2: '/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg',
  oppen: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
  para: '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg',
  eeaao: '/w3LxiVYdWWRvEVdn5RYq6jIqkb1.jpg',
  lala: '/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg',
  inter: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
  whip: '/7fn624j5lj3xTme2SgiLCeuedmO.jpg',
  spirit: '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg',
  knives: '/pThyQovXQrw2m0s9x82twj48Jq4.jpg',
  br2049: '/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg',
  gbh: '/eWdyYQreja6JGCzqHWXpWHDrrPo.jpg',
  getout: '/tFXcEccSQMf3lfhfXKSU9iRBpa3.jpg',
  past: '/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg',
  arriv: '/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
  madmax: '/hA2ple9q4qnwxp3hKVNhroipsir.jpg',
  portrait: '/2LquGwHGdJBdConUt5XJfRtkUUE.jpg'
};
// Prefer inlined blob URLs (set by the standalone bundler via
// <meta ext-resource-dependency>) when present; otherwise hit the TMDB CDN.
const __AG_RES = (typeof window !== 'undefined' && window.__resources) || {};
const POSTERS = Object.fromEntries(
  Object.entries(POSTER_PATHS).map(([k, p]) => [k, __AG_RES['poster_' + k] || (TMDB + p)])
);

// People
const ME = { name: 'Maya Okonkwo', handle: '@mayao', avatar: '#FF6A5C', watched: 212, reviews: 48 };
const FRIENDS = [
{ name: 'Leo Park', handle: '@leop', avatar: '#8B6CFF', watched: 184, reviews: 31, on: true },
{ name: 'Sana Iyer', handle: '@sana', avatar: '#46D4A0', watched: 309, reviews: 77, on: true },
{ name: 'Theo Brandt', handle: '@theob', avatar: '#FFC24B', watched: 96, reviews: 12, on: false },
{ name: 'Nadia Reyes', handle: '@nadiar', avatar: '#FF8FB1', watched: 241, reviews: 54, on: true },
{ name: 'Kojo Mensah', handle: '@kojo', avatar: '#5C9BE0', watched: 130, reviews: 22, on: false },
{ name: 'Ivy Chen', handle: '@ivyc', avatar: '#E0518F', watched: 178, reviews: 40, on: true }];

const initials = (n) => n.split(' ').map((w) => w[0]).join('').slice(0, 2);

// ───────────────────────── Icons ─────────────────────────
function Ic({ name, size = 22, c = 'currentColor', sw = 1.8, fill = 'none', style }) {
  const p = { fill, stroke: c, strokeWidth: sw, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const paths = {
    home: <><path d="M3 10.5 12 3l9 7.5" {...p} /><path d="M5 9.5V20h14V9.5" {...p} /></>,
    search: <><circle cx="11" cy="11" r="7" {...p} /><path d="m20 20-3.2-3.2" {...p} /></>,
    cards: <><rect x="6" y="4.5" width="12" height="15" rx="2.4" {...p} transform="rotate(-7 12 12)" /></>,
    library: <><path d="M5 4h3v16H5zM10 4h3v16h-3z" {...p} /><path d="m16 5 3 .6 .6 14.4-3-.6z" {...p} /></>,
    user: <><circle cx="12" cy="8" r="4" {...p} /><path d="M4.5 20a7.5 7.5 0 0 1 15 0" {...p} /></>,
    heart: <path d="M12 20s-7-4.6-9.2-9C1.3 8 2.8 4.5 6.2 4.5c2 0 3.2 1.2 3.8 2.3.6-1.1 1.8-2.3 3.8-2.3 3.4 0 4.9 3.5 3.4 6.5C19 15.4 12 20 12 20Z" {...p} />,
    heartF: <path d="M12 20s-7-4.6-9.2-9C1.3 8 2.8 4.5 6.2 4.5c2 0 3.2 1.2 3.8 2.3.6-1.1 1.8-2.3 3.8-2.3 3.4 0 4.9 3.5 3.4 6.5C19 15.4 12 20 12 20Z" fill={c} stroke={c} strokeWidth={sw} />,
    plus: <><path d="M12 5v14M5 12h14" {...p} /></>,
    bell: <><path d="M6 9a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6Z" {...p} /><path d="M10 20a2 2 0 0 0 4 0" {...p} /></>,
    check: <path d="m5 12.5 4.5 4.5L19 6.5" {...p} />,
    x: <path d="M6 6l12 12M18 6 6 18" {...p} />,
    star: <path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8L4.5 9.7l5.9-.9z" fill={c} stroke={c} strokeWidth="0.5" />,
    starO: <path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8L4.5 9.7l5.9-.9z" {...p} />,
    clock: <><circle cx="12" cy="12" r="8.5" {...p} /><path d="M12 7.5V12l3 1.8" {...p} /></>,
    play: <path d="M8 5.5v13l11-6.5z" fill={c} stroke={c} strokeWidth={sw} />,
    bookmark: <path d="M6 4h12v16l-6-4-6 4z" {...p} />,
    bookmarkF: <path d="M6 4h12v16l-6-4-6 4z" fill={c} stroke={c} strokeWidth={sw} />,
    eye: <><path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" {...p} /><circle cx="12" cy="12" r="3" {...p} /></>,
    dislike: <><path d="M7 11V4h10l2 7v9H9l-1-4H4a1.5 1.5 0 0 1-1.4-2l1.6-5A2 2 0 0 1 6 7" {...p} /></>,
    sliders: <><path d="M4 7h11M4 17h7" {...p} /><circle cx="18" cy="7" r="2.5" {...p} /><circle cx="14" cy="17" r="2.5" {...p} /></>,
    chevron: <path d="m9 5 7 7-7 7" {...p} />,
    chevL: <path d="m15 5-7 7 7 7" {...p} />,
    chevDown: <path d="m5 9 7 7 7-7" {...p} />,
    arrow: <><path d="M4 12h15M13 6l6 6-6 6" {...p} /></>,
    settings: <><circle cx="12" cy="12" r="3.1" {...p} /><path d="M19.4 13a1.65 1.65 0 0 0 .33 1.82l.05.05a2 2 0 1 1-2.83 2.83l-.05-.05a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.08a1.65 1.65 0 0 0-1.08-1.51 1.65 1.65 0 0 0-1.82.33l-.05.05a2 2 0 1 1-2.83-2.83l.05-.05A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.08a1.65 1.65 0 0 0 1.51-1.08 1.65 1.65 0 0 0-.33-1.82l-.05-.05a2 2 0 1 1 2.83-2.83l.05.05A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.08a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.05-.05a2 2 0 1 1 2.83 2.83l-.05.05A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.08a1.65 1.65 0 0 0-1.51 1z" {...p} /></>,
    film: <><rect x="3.5" y="4.5" width="17" height="15" rx="2.5" {...p} /><path d="M8 4.5v15M16 4.5v15M3.5 9.5h4.5M3.5 14.5h4.5M16 9.5h4.5M16 14.5h4.5" {...p} /></>,
    users: <><circle cx="9" cy="9" r="3.2" {...p} /><path d="M3.5 19a5.5 5.5 0 0 1 11 0" {...p} /><path d="M16 6.2A3.2 3.2 0 0 1 16 12.5M21 19a5.5 5.5 0 0 0-4-5.3" {...p} /></>,
    sparkle: <><path d="M12 3.5v5M12 15.5v5M4.5 12h5M14.5 12h5" {...p} /><path d="M7 7l2.5 2.5M14.5 14.5 17 17M17 7l-2.5 2.5M9.5 14.5 7 17" {...p} strokeWidth={sw * 0.8} /></>,
    dice: <><rect x="4" y="4" width="16" height="16" rx="4" {...p} /><circle cx="9" cy="9" r="1.3" fill={c} stroke="none" /><circle cx="15" cy="9" r="1.3" fill={c} stroke="none" /><circle cx="12" cy="12" r="1.3" fill={c} stroke="none" /><circle cx="9" cy="15" r="1.3" fill={c} stroke="none" /><circle cx="15" cy="15" r="1.3" fill={c} stroke="none" /></>,
    undo: <><path d="M4 9h10a5 5 0 0 1 0 10H9" {...p} /><path d="m7 6-3 3 3 3" {...p} /></>,
    edit: <><path d="M14 5l5 5M4 20l1-4L16 5l4 4L9 20z" {...p} /></>,
    logo: <><circle cx="12" cy="12" r="9" {...p} /><path d="M9.5 9.5v5l4.5-2.5z" fill={c} stroke="none" /></>,
    arrowUp: <><path d="M12 20V5M6 11l6-6 6 6" {...p} /></>,
    arrowDown: <><path d="M12 4v15M6 13l6 6 6-6" {...p} /></>,
    mail: <><rect x="3" y="5" width="18" height="14" rx="2.4" {...p} /><path d="m4 7 8 6 8-6" {...p} /></>,
    logout: <><path d="M15 5H6a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h9" {...p} /><path d="M11 12h9M17 8l4 4-4 4" {...p} /></>,
    refresh: <><path d="M20 11a8 8 0 1 0-.6 4" {...p} /><path d="M20 5v6h-6" {...p} /></>,
    wifiOff: <><path d="M3 8.5a16 16 0 0 1 6-3.2M21 8.5a16 16 0 0 0-6.5-3.3M6.5 12.5a10 10 0 0 1 4-2.1M17.5 12.5a10 10 0 0 0-2.5-1.6M9.5 16a5 5 0 0 1 5 0" {...p} /><circle cx="12" cy="19.5" r="0.6" fill={c} stroke={c} /><path d="m3 3 18 18" {...p} strokeWidth={sw * 1.1} /></>,
    shield: <><path d="M12 3l7 3v5c0 4.6-3 8-7 10-4-2-7-5.4-7-10V6z" {...p} /></>,
    vote: <><path d="M9 12.5 11 14.5 15.5 10" {...p} /><rect x="4" y="4.5" width="16" height="15" rx="2.4" {...p} /></>,
    trophy: <><path d="M7 4h10v4a5 5 0 0 1-10 0z" {...p} /><path d="M7 6H4.5a2.5 2.5 0 0 0 2.5 4M17 6h2.5a2.5 2.5 0 0 1-2.5 4M9 19h6M10 15v4M14 15v4" {...p} /></>,
    bulb: <><path d="M9 18h6M10 21h4M12 3a6 6 0 0 1 4 10.5c-.7.7-1 1.2-1 2.5H9c0-1.3-.3-1.8-1-2.5A6 6 0 0 1 12 3Z" {...p} /></>,
    moon: <><path d="M20 14.5A8 8 0 1 1 9.5 4 6.5 6.5 0 0 0 20 14.5Z" {...p} /></>,
    share: <><circle cx="6" cy="12" r="2.6" {...p} /><circle cx="17" cy="6" r="2.6" {...p} /><circle cx="17" cy="18" r="2.6" {...p} /><path d="m8.3 10.8 6.4-3.6M8.3 13.2l6.4 3.6" {...p} /></>
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={style} aria-hidden="true">
      {paths[name] || null}
    </svg>);

}

// ───────────────────────── Poster ─────────────────────────
// Original styled placeholder: cinematic gradient + grain + typeset title.
function Poster({ m, w = 132, r = 14, showTitle = true, badge = null }) {
  const h = Math.round(w * 1.5);
  const titleSize = Math.max(11, Math.round(w * 0.115));
  return (
    <div style={{
      width: w, height: h, borderRadius: r, position: 'relative', overflow: 'hidden',
      flexShrink: 0, background: `linear-gradient(150deg, ${m.c1} 0%, ${m.c2} 92%)`,
      boxShadow: '0 10px 26px rgba(0,0,0,0.45)'
    }}>
      {/* texture: soft radial bloom */}
      <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(120% 80% at 75% 8%, ${hexA(m.c1, 0.65)} 0%, transparent 55%)` }} />
      {/* grain stripes */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.10,
        backgroundImage: 'repeating-linear-gradient(115deg, #fff 0 1px, transparent 1px 7px)' }} />
      {/* vignette */}
      <div style={{ position: 'absolute', inset: 0, boxShadow: 'inset 0 -40% 60px -20px rgba(0,0,0,0.7), inset 0 0 0 1px rgba(255,255,255,0.07)' }} />
      {/* letterbox top hairline + dot motif */}
      <div style={{ position: 'absolute', top: r * 0.7, left: r * 0.7, display: 'flex', gap: 4 }}>
        {[0, 1, 2].map((i) => <div key={i} style={{ width: 4, height: 4, borderRadius: 9, background: 'rgba(255,255,255,0.55)' }} />)}
      </div>
      {badge}
      {showTitle &&
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: `${r * 0.85}px ${r * 0.8}px ${r * 0.75}px`, zIndex: 1 }}>
          <div style={{
          fontFamily: T.disp, fontWeight: 800, color: '#fff', fontSize: titleSize,
          lineHeight: 1.04, letterSpacing: -0.3, textShadow: '0 2px 10px rgba(0,0,0,0.5)'
        }}>{m.t}</div>
        </div>
      }
      {POSTERS[m.id] &&
      <img src={POSTERS[m.id]} alt={m.t} loading="lazy"
      onError={(e) => {e.currentTarget.style.display = 'none';}}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', zIndex: 2, objectFit: "cover", opacity: "1" }} />
      }
    </div>);

}
function hexA(hex, a) {const n = parseInt(hex.slice(1), 16);return `rgba(${n >> 16 & 255},${n >> 8 & 255},${n & 255},${a})`;}

// ───────────────────────── Prototype navigation ─────────────────────────
// The interactive host (Agreeo Daylight.html) registers handlers via setNav().
// Components call go()/back()/resetTo() from onClick. No-ops in the static canvas.
let __nav = { go() {}, back() {}, reset() {} };
const go = (id) => __nav.go(id);
const back = () => __nav.back();
const resetTo = (id) => __nav.reset(id);
const setNav = (n) => {__nav = n;};
const tap = (id) => ({ onClick: (e) => {e.stopPropagation();go(id);}, style: { cursor: 'pointer' } });

// ───────────────────────── Small UI atoms ─────────────────────────
function Stars({ r, size = 12 }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
      <Ic name="star" size={size} c={T.gold} />
      <span style={{ fontFamily: T.ui, fontWeight: 700, fontSize: size, color: T.text }}>{r.toFixed(1)}</span>
    </span>);

}

function Chip({ children, active = false, icon, style }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, whiteSpace: 'nowrap',
      padding: icon ? '8px 13px 8px 11px' : '8px 14px', borderRadius: 999,
      fontFamily: T.ui, fontWeight: 600, fontSize: 13, letterSpacing: -0.1,
      color: active ? T.onText : T.sub,
      background: active ? T.text : T.surface,
      border: `1px solid ${active ? 'transparent' : T.line}`,
      ...style
    }}>
      {icon && <Ic name={icon} size={15} c={active ? T.onText : T.sub} />}
      {children}
    </div>);

}

function Avatar({ person, size = 44, ring = false }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      background: `linear-gradient(145deg, ${person.avatar}, ${hexA(person.avatar, 0.55)})`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: T.disp, fontWeight: 700, fontSize: size * 0.36, color: '#fff',
      boxShadow: ring ? `0 0 0 2px ${T.bg}, 0 0 0 4px ${person.avatar}` : 'inset 0 1px 2px rgba(255,255,255,0.25)'
    }}>{initials(person.name)}</div>);

}

// Gradient pill button
function GButton({ children, icon, full, onDark, style, onClick }) {
  return (
    <div onClick={onClick ? (e) => {e.stopPropagation();onClick(e);} : undefined} style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9,
      height: 54, borderRadius: 16, width: full ? '100%' : undefined, padding: full ? 0 : '0 24px',
      background: T.grad, color: '#fff', fontFamily: T.ui, fontWeight: 800, fontSize: 16, letterSpacing: -0.2, whiteSpace: 'nowrap',
      boxShadow: '0 10px 26px -8px rgba(139,108,255,0.6)', cursor: onClick ? 'pointer' : 'default', ...style
    }}>
      {icon && <Ic name={icon} size={20} c="#fff" sw={2.1} />}
      {children}
    </div>);

}
function SButton({ children, icon, full, style, onClick }) {
  return (
    <div onClick={onClick ? (e) => {e.stopPropagation();onClick(e);} : undefined} style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9,
      height: 54, borderRadius: 16, width: full ? '100%' : undefined, padding: full ? 0 : '0 22px',
      background: T.surface, color: T.text, fontFamily: T.ui, fontWeight: 700, fontSize: 16, whiteSpace: 'nowrap',
      border: `1px solid ${T.line2}`, cursor: onClick ? 'pointer' : 'default', ...style
    }}>
      {icon && <Ic name={icon} size={20} c={T.text} />}
      {children}
    </div>);

}

// Status-bar safe top spacer (clears dynamic island)
function TopSafe({ h = 58 }) {return <div style={{ height: h, flexShrink: 0 }} />;}

// Bottom tab bar — floating glass
function BottomNav({ active = 'home' }) {
  const tabs = [
  { k: 'home', icon: 'home', label: 'Home' },
  { k: 'swipe', icon: 'cards', label: 'Swipe' },
  { k: 'night', icon: 'film', label: '', center: true },
  { k: 'library', icon: 'library', label: 'Library' },
  { k: 'friends', icon: 'users', label: 'Friends' }];

  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, paddingBottom: 26, zIndex: 40,
      background: `linear-gradient(to top, ${T.bg} 55%, transparent)` }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-around',
        margin: '0 14px', height: 62, borderRadius: 24, position: 'relative',
        background: T.glass, backdropFilter: 'blur(18px)', WebkitBackdropFilter: 'blur(18px)',
        border: `1px solid ${T.line2}`, boxShadow: '0 12px 30px -10px rgba(0,0,0,0.6)' }}>
        {tabs.map((t) => t.center ?
        <div key={t.k} onClick={(e) => {e.stopPropagation();go('mn_create');}} style={{ width: 50, height: 50, borderRadius: 17, background: T.grad, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: -22,
          boxShadow: '0 10px 22px -6px rgba(139,108,255,0.7)', border: `3px solid ${T.bg}` }}>
            <Ic name="film" size={24} c="#fff" sw={2} />
          </div> :

        <div key={t.k} onClick={(e) => {e.stopPropagation();go(t.k === 'swipe' ? 'swipe' : t.k === 'library' ? 'library' : t.k === 'friends' ? 'friends' : 'home');}}
        style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, width: 54, cursor: 'pointer' }}>
            <Ic name={t.icon} size={23} c={active === t.k ? T.red : T.faint} sw={active === t.k ? 2.2 : 1.8}
          fill={active === t.k && t.icon === 'home' ? 'none' : 'none'} />
            <span style={{ fontFamily: T.ui, fontWeight: active === t.k ? 700 : 600, fontSize: 10,
            color: active === t.k ? T.text : T.faint }}>{t.label}</span>
          </div>
        )}
      </div>
    </div>);

}

// Generic screen shell (warm-black bg, fills device)
function Screen({ children, pad = true, bg = T.bg, style }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: bg, color: T.text,
      fontFamily: T.ui, display: 'flex', flexDirection: 'column', overflow: 'hidden', ...style }}>
      {children}
    </div>);

}

// Section header row (title + optional action)
function RowHead({ title, action, sub }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', padding: '0 20px', marginBottom: 13 }}>
      <div>
        <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 20, letterSpacing: -0.4, color: T.text, whiteSpace: 'nowrap' }}>{title}</div>
        {sub && <div style={{ fontFamily: T.ui, fontSize: 12.5, color: T.faint, marginTop: 2 }}>{sub}</div>}
      </div>
      {action && <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 13, color: T.red }}>{action}</div>}
    </div>);

}

Object.assign(window, {
  T, MOVIES, byId, runtime, ALL_GENRES, ME, FRIENDS, initials, hexA,
  Ic, Poster, Stars, Chip, Avatar, GButton, SButton, TopSafe, BottomNav, Screen, RowHead,
  go, back, resetTo, setNav, tap, POSTERS, TMDB
});