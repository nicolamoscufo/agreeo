// ag-main.jsx — Home, Swipe, Library

// ── Home ──
function HomeScreen() {
  const recs = ['dune2', 'inter', 'para', 'eeaao', 'br2049'];
  const trending = ['oppen', 'whip', 'knives', 'madmax'];
  return (
    <Screen>
      <BottomNav active="home" />
      <div style={{ flex: 1, overflow: 'hidden' }}>
        <TopSafe />
        {/* greeting + bell */}
        <div style={{ padding: '4px 20px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontFamily: T.ui, fontSize: 13, color: T.faint, fontWeight: 600 }}>Friday night, Maya</div>
            <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 25, letterSpacing: -0.6, color: T.text, whiteSpace: 'nowrap' }}>What's the move?</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div onClick={() => go('notifs')} style={{ position: 'relative', width: 44, height: 44, borderRadius: 14, background: T.surface, border: `1px solid ${T.line}`, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Ic name="bell" size={21} c={T.text} />
              <div style={{ position: 'absolute', top: 9, right: 10, width: 9, height: 9, borderRadius: '50%', background: T.red, border: `2px solid ${T.surface}` }} />
            </div>
            <div onClick={() => go('profile')} style={{ cursor: 'pointer' }}><Avatar person={ME} size={44} /></div>
          </div>
        </div>
        {/* search */}
        <div style={{ padding: '0 20px 12px', display: 'flex', gap: 10 }}>
          <div style={{ flex: 1, height: 46, borderRadius: 14, background: T.surface, border: `1px solid ${T.line}`,
            display: 'flex', alignItems: 'center', gap: 9, padding: '0 14px' }}>
            <Ic name="search" size={19} c={T.faint} />
            <span style={{ fontFamily: T.ui, fontSize: 14.5, color: T.faint }}>Search films, people…</span>
          </div>
          <div onClick={() => go('filters')} style={{ width: 46, height: 46, borderRadius: 14, background: T.surface, border: `1px solid ${T.line}`, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="sliders" size={20} c={T.text} /></div>
          <div onClick={() => go('mood')} style={{ width: 46, height: 46, borderRadius: 14, cursor: 'pointer', background: T.grad,
            display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 20px -8px rgba(139,108,255,0.6)' }}><Ic name="sparkle" size={21} c="#fff" /></div>
        </div>
        {/* filter chips */}
        <div style={{ display: 'flex', gap: 8, padding: '0 20px 16px', overflow: 'hidden' }}>
          <Chip active icon="sparkle">For you</Chip>
          <Chip>Under 2h</Chip>
          <Chip>Sci-Fi</Chip>
          <Chip>Movies</Chip>
        </div>

        {/* Movie Night CTA */}
        <div style={{ padding: '0 20px 20px' }}>
          <div style={{ position: 'relative', borderRadius: 22, overflow: 'hidden', padding: '18px 18px', background: T.grad, cursor: 'pointer',
            boxShadow: '0 16px 34px -14px rgba(139,108,255,0.7)' }} onClick={() => go('mn_create')}>
            <div style={{ position: 'absolute', inset: 0, opacity: 0.16,
              backgroundImage: 'repeating-linear-gradient(125deg,#fff 0 1px, transparent 1px 9px)' }} />
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 19, color: '#fff', letterSpacing: -0.4 }}>Start a Movie Night</div>
                <div style={{ fontFamily: T.ui, fontSize: 12.5, color: 'rgba(255,255,255,0.85)', marginTop: 3, lineHeight: 1.4 }}>Invite friends, swipe together, agree in minutes.</div>
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, marginTop: 12, padding: '9px 15px', borderRadius: 11,
                  background: 'rgba(255,255,255,0.95)', fontFamily: T.ui, fontWeight: 800, fontSize: 13.5, color: '#1a0e10' }}>
                  <Ic name="plus" size={16} c="#1a0e10" sw={2.6} />New session</div>
              </div>
              <div style={{ display: 'flex' }}>
                {FRIENDS.slice(0, 3).map((f, i) => <div key={i} style={{ marginLeft: i ? -14 : 0 }}><Avatar person={f} size={42} ring /></div>)}
              </div>
            </div>
          </div>
        </div>

        {/* Recommended row */}
        <RowHead title="Made for you" action="See all" />
        <div style={{ display: 'flex', gap: 14, padding: '0 20px 22px', overflow: 'hidden' }}>
          {recs.map((id) => {
            const m = byId(id);
            return (
              <div key={id} style={{ width: 132 }} {...tap('detail')}>
                <Poster m={m} w={132} />
                <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'nowrap', gap: 7, marginTop: 9, whiteSpace: 'nowrap' }}>
                  <Stars r={m.r} /><span style={{ fontFamily: T.ui, fontSize: 12, color: T.faint, whiteSpace: 'nowrap' }}>· {m.y}</span>
                </div>
              </div>);

          })}
        </div>

        {/* Random pick */}
        <div style={{ padding: '0 20px 18px' }}>
          <div style={{ borderRadius: 18, background: T.surface, border: `1px solid ${T.line}`, padding: '14px 16px',
            display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ width: 48, height: 48, borderRadius: 14, background: T.gradSoft, border: `1px solid ${T.line2}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="dice" size={26} c={T.gold} /></div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 16, color: T.text }}>Can't decide?</div>
              <div style={{ fontFamily: T.ui, fontSize: 12.5, color: T.sub, marginTop: 1 }}>Pull a random pick from your watchlist</div>
            </div>
            <div onClick={() => go('random')} style={{ padding: '10px 14px', borderRadius: 12, background: T.text, fontFamily: T.ui, fontWeight: 800, fontSize: 13, color: T.onText, cursor: 'pointer' }}>Surprise me</div>
          </div>
        </div>

        {/* Trending grid peek */}
        <RowHead title="Trending with friends" />
        <div style={{ display: 'flex', gap: 14, padding: '0 20px 110px', overflow: 'hidden' }}>
          {trending.map((id) => {const m = byId(id);return <div key={id} {...tap('detail')}><Poster m={m} w={108} /></div>;})}
        </div>
      </div>
    </Screen>);

}

// ── Swipe ── (full-bleed poster card)
function SwipeScreen() {
  const m = byId('br2049');
  const Stamp = ({ label, color, side }) =>
  <div style={{ position: 'absolute', top: 102, [side]: 24, transform: `rotate(${side === 'left' ? -14 : 14}deg)`, zIndex: 5,
    border: `3.5px solid ${color}`, borderRadius: 12, padding: '5px 15px', background: 'rgba(0,0,0,0.18)',
    backdropFilter: 'blur(4px)', WebkitBackdropFilter: 'blur(4px)', fontFamily: T.disp, fontWeight: 800, fontSize: 28, letterSpacing: 1,
    color, opacity: 0.95, boxShadow: `0 6px 22px -6px ${hexA(color, 0.7)}` }}>{label}</div>;

  const Act = ({ icon, c, big, onClick }) =>
  <div onClick={onClick ? (e) => {e.stopPropagation();onClick(e);} : undefined} style={{ width: big ? 64 : 52, height: big ? 64 : 52, borderRadius: '50%', cursor: 'pointer',
    background: T.surface, border: `1px solid ${T.line2}`,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    boxShadow: big ? `0 12px 26px -8px ${hexA(c, 0.6)}` : '0 8px 18px -8px rgba(0,0,0,0.6)' }}>
      <Ic name={icon} size={big ? 28 : 23} c={c} sw={2.1} />
    </div>;

  return (
    <Screen bg="#000">
      {/* full-bleed poster */}
      <div style={{ position: 'absolute', inset: 0, background: `linear-gradient(155deg, ${m.c1} 0%, ${m.c2} 90%)` }} />
      {POSTERS[m.id] &&
      <img src={POSTERS[m.id]} alt={m.t} onError={(e) => {e.currentTarget.style.display = 'none';}}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 200, background: 'linear-gradient(to bottom, rgba(0,0,0,0.6) 0%, transparent 100%)' }} />
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.92) 0%, rgba(0,0,0,0.5) 24%, rgba(0,0,0,0.12) 42%, transparent 58%)' }} />
      {/* tap layer → details */}
      <div onClick={() => go('detail')} style={{ position: 'absolute', inset: 0, cursor: 'pointer', zIndex: 2 }} />

      <BottomNav active="swipe" />

      {/* header */}
      <TopSafe />
      <div style={{ position: 'absolute', top: 58, left: 0, right: 0, padding: '2px 20px 0', zIndex: 6,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 23, letterSpacing: -0.5, color: '#fff', textShadow: '0 2px 12px rgba(0,0,0,0.5)' }}>Discover</div>
          <div style={{ fontFamily: T.ui, fontSize: 12.5, color: 'rgba(255,255,255,0.78)', marginTop: 1 }}>Swipe to build your taste</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ padding: '7px 13px', borderRadius: 999, background: 'rgba(255,255,255,0.18)',
            backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.28)',
            fontFamily: T.ui, fontWeight: 700, fontSize: 12.5, color: '#fff' }}>23 left</div>
          <div onClick={(e) => {e.stopPropagation();go('profile');}} style={{ cursor: 'pointer' }}><Avatar person={ME} size={42} /></div>
        </div>
      </div>

      {/* swipe-direction stamps */}
      <Stamp label="LIKE" color={T.green} side="right" />
      <Stamp label="NOPE" color={T.red} side="left" />

      {/* meta */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 196, padding: '0 24px', zIndex: 6, pointerEvents: 'none' }}>
        <div style={{ display: 'flex', gap: 7, marginBottom: 12 }}>
          {m.g.map((g) => <span key={g} style={{ padding: '5px 12px', borderRadius: 999, background: 'rgba(255,255,255,0.18)',
            backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.22)',
            fontFamily: T.ui, fontWeight: 700, fontSize: 11.5, color: '#fff' }}>{g}</span>)}
        </div>
        <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 35, color: '#fff', letterSpacing: -0.7, lineHeight: 1.0, textShadow: '0 3px 18px rgba(0,0,0,0.55)' }}>{m.t}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '11px 0 11px', fontFamily: T.ui, fontSize: 13.5, color: 'rgba(255,255,255,0.9)', fontWeight: 600 }}>
          <span>{m.y}</span><span style={{ opacity: 0.5 }}>·</span><span>{runtime(m.m)}</span><span style={{ opacity: 0.5 }}>·</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Ic name="star" size={14} c={T.gold} /><span style={{ fontWeight: 700, color: '#fff' }}>{m.r.toFixed(1)}</span></span>
        </div>
        <div style={{ fontFamily: T.ui, fontSize: 13.5, color: 'rgba(255,255,255,0.84)', lineHeight: 1.5, textShadow: '0 1px 8px rgba(0,0,0,0.4)' }}>{m.d}</div>
      </div>

      {/* action bar */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 104, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 16, zIndex: 46 }}>
        <Act icon="undo" c={T.faint} onClick={() => back()} />
        <Act icon="x" c={T.red} big />
        <Act icon="bookmark" c={T.purple} />
        <Act icon="heartF" c={T.green} big onClick={() => go('detail')} />
        <Act icon="eye" c={T.gold} />
      </div>
    </Screen>);

}

// ── Library ──
// Each film belongs to exactly ONE section. Watchlist = still to watch.
// Liked = watched & loved. Watched = seen (log/history). No cross-listing.
const LIB_BADGE = {
  watchlist: { label: 'Watchlist', c: () => T.purple },
  liked: { label: '★ Liked', c: () => T.green },
  watched: { label: 'Watched', c: () => T.gold }
};
const LIBRARY = [
{ id: 'dune2', status: 'watchlist' },
{ id: 'oppen', status: 'watchlist' },
{ id: 'lala', status: 'watchlist' },
{ id: 'arriv', status: 'watchlist' },
{ id: 'madmax', status: 'watchlist' },
{ id: 'past', status: 'watchlist' },
{ id: 'para', status: 'liked', review: 'A masterclass in tension. Stayed with me for days.' },
{ id: 'eeaao', status: 'liked' },
{ id: 'spirit', status: 'liked', review: 'Pure imagination. The most tender film about growing up.' },
{ id: 'gbh', status: 'liked' },
{ id: 'inter', status: 'watched', review: 'Cried twice. The docking scene is unreal.' },
{ id: 'whip', status: 'watched' },
{ id: 'knives', status: 'watched' },
{ id: 'br2049', status: 'watched', review: 'Every frame a painting. Slow, gorgeous, worth it.' }];

const LIB_COUNTS = { watchlist: 14, liked: 58, watched: 212 };

function LibraryRow({ id, status, review }) {
  const m = byId(id);
  const b = LIB_BADGE[status];
  const badgeC = b.c();
  return (
    <div style={{ display: 'flex', gap: 13, padding: '12px 0', borderBottom: `1px solid ${T.line}`, cursor: 'pointer' }} onClick={() => go('detail')}>
      <Poster m={m} w={66} r={10} showTitle={false} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 8 }}>
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 15.5, color: T.text, lineHeight: 1.1 }}>{m.t}</div>
          <div style={{ padding: '4px 9px', borderRadius: 8, background: hexA(badgeC, 0.16), flexShrink: 0,
              fontFamily: T.ui, fontWeight: 700, fontSize: 10.5, color: badgeC, whiteSpace: 'nowrap' }}>{b.label}</div>
        </div>
        <div style={{ fontFamily: T.ui, fontSize: 12, color: T.faint, margin: '4px 0 6px' }}>{m.y} · {runtime(m.m)} · {m.g.join(', ')}</div>
        {review ?
        <div style={{ fontFamily: T.ui, fontSize: 12, color: T.sub, fontStyle: 'italic', lineHeight: 1.4,
          borderLeft: `2px solid ${T.line2}`, paddingLeft: 9 }}>"{review}"</div> :
        status === 'watchlist' ?
        <div style={{ display: 'flex', gap: 8, marginTop: 'auto' }}>
            <Qa icon="heart" />
            <Qa icon="dislike" />
            <Qa icon="eye" />
            <Qa icon="edit" label="Review" />
          </div> :
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 'auto' }}>
            <Stars r={m.r} />
            <span style={{ fontFamily: T.ui, fontSize: 12, color: T.faint }}>· your rating</span>
          </div>
        }
      </div>
    </div>);

}
function Qa({ icon, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 5, padding: label ? '6px 10px' : '6px', borderRadius: 9,
      background: T.surface2, border: `1px solid ${T.line}` }}>
      <Ic name={icon} size={15} c={T.sub} />
      {label && <span style={{ fontFamily: T.ui, fontWeight: 600, fontSize: 11.5, color: T.sub }}>{label}</span>}
    </div>);

}
function LibraryScreen() {
  const [tab, setTab] = React.useState('watchlist');
  const rows = LIBRARY.filter((it) => it.status === tab);
  return (
    <Screen>
      <BottomNav active="library" />
      <div style={{ flex: 1, overflow: 'hidden' }}>
        <TopSafe />
        <div style={{ padding: '2px 20px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 27, letterSpacing: -0.6, color: T.text, whiteSpace: 'nowrap' }}>Your Library</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div onClick={(e) => {e.stopPropagation();go('search_empty');}} style={{ width: 42, height: 42, borderRadius: 13, background: T.surface, border: `1px solid ${T.line}`, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="search" size={20} c={T.text} /></div>
            <div onClick={(e) => {e.stopPropagation();go('profile');}} style={{ cursor: 'pointer' }}><Avatar person={ME} size={42} /></div>
          </div>
        </div>
        {/* tabs */}
        <div style={{ display: 'flex', gap: 6, margin: '0 20px 6px', padding: 5, borderRadius: 14, background: T.surface, border: `1px solid ${T.line}` }}>
          {[['Watchlist', 'watchlist'], ['Liked', 'liked'], ['Watched', 'watched']].map(([label, k]) => {
            const on = tab === k;
            return (
              <div key={k} onClick={(e) => {e.stopPropagation();setTab(k);}} style={{ flex: 1, height: 38, borderRadius: 10, cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                background: on ? T.grad : 'transparent', fontFamily: T.ui, fontWeight: 700, fontSize: 13.5, color: on ? '#fff' : T.sub }}>
                {label}<span style={{ fontSize: 11, opacity: 0.8 }}>{LIB_COUNTS[k]}</span></div>);

          })}
        </div>
        <div style={{ flex: 1, overflow: 'hidden', padding: '8px 20px 110px' }}>
          {rows.map((it) => <LibraryRow key={it.id} id={it.id} status={it.status} review={it.review} />)}
        </div>
      </div>
    </Screen>);

}

Object.assign(window, { HomeScreen, SwipeScreen, LibraryScreen });