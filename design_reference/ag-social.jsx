// ag-social.jsx — Friends + Movie Night flow (Create, Waiting, Voting, Results)

// ── Friends ──
function FriendsScreen() {
  const requests = [FRIENDS[4], FRIENDS[5]];
  return (
    <Screen>
      <BottomNav active="friends" />
      <div style={{ flex: 1, overflow: 'hidden' }}>
        <TopSafe />
        <div style={{ padding: '2px 20px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 27, letterSpacing: -0.6, color: T.text }}>Friends</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div onClick={() => go('addfriends')} style={{ width: 42, height: 42, borderRadius: 13, background: T.surface, border: `1px solid ${T.line}`, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="plus" size={22} c={T.text} sw={2.2} /></div>
            <div onClick={() => go('profile')} style={{ cursor: 'pointer' }}><Avatar person={ME} size={42} /></div>
          </div>
        </div>
        {/* search */}
        <div style={{ padding: '0 20px 18px' }}>
          <div onClick={() => go('addfriends')} style={{ height: 46, borderRadius: 14, background: T.surface, border: `1px solid ${T.line}`, cursor: 'pointer',
            display: 'flex', alignItems: 'center', gap: 9, padding: '0 14px' }}>
            <Ic name="search" size={19} c={T.faint} />
            <span style={{ fontFamily: T.ui, fontSize: 14.5, color: T.faint }}>Find friends by name…</span>
          </div>
        </div>
        <div style={{ flex: 1, overflow: 'hidden', padding: '0 20px 110px' }}>
          {/* requests */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
            <span style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 15, color: T.text }}>Requests</span>
            <span style={{ width: 20, height: 20, borderRadius: '50%', background: T.red, fontFamily: T.ui, fontWeight: 800, fontSize: 11,
              color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>2</span>
          </div>
          {requests.map((f, i) =>
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', marginBottom: 10,
            borderRadius: 16, background: T.surface, border: `1px solid ${T.line}` }}>
              <Avatar person={f} size={46} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 15, color: T.text }}>{f.name}</div>
                <div style={{ fontFamily: T.ui, fontSize: 12, color: T.faint }}>{f.handle} · 3 mutual</div>
              </div>
              <div style={{ width: 38, height: 38, borderRadius: 11, background: T.grad, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Ic name="check" size={19} c="#fff" sw={2.6} /></div>
              <div style={{ width: 38, height: 38, borderRadius: 11, background: T.surface2, border: `1px solid ${T.line2}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="x" size={18} c={T.sub} /></div>
            </div>
          )}
          {/* all friends */}
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 15, color: T.text, margin: '18px 0 12px' }}>All friends · 24</div>
          {FRIENDS.slice(0, 4).map((f, i) =>
          <div key={i} onClick={() => go('friendp')} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '10px 0', borderBottom: `1px solid ${T.line}`, cursor: 'pointer' }}>
              <div style={{ position: 'relative' }}>
                <Avatar person={f} size={46} />
                {f.on && <div style={{ position: 'absolute', bottom: 1, right: 1, width: 12, height: 12, borderRadius: '50%', background: T.green, border: `2.5px solid ${T.bg}` }} />}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 15, color: T.text }}>{f.name}</div>
                <div style={{ fontFamily: T.ui, fontSize: 12, color: T.faint }}>{f.watched} watched · {f.reviews} reviews</div>
              </div>
              <div style={{ padding: '8px 14px', borderRadius: 11, background: T.gradSoft, border: `1px solid ${T.line2}`,
              fontFamily: T.ui, fontWeight: 700, fontSize: 12.5, color: T.text }}>Invite</div>
            </div>
          )}
        </div>
        {/* start movie night floating */}
        <div style={{ position: 'absolute', left: 20, right: 20, bottom: 96, zIndex: 45 }}>
          <GButton full icon="film" onClick={() => go('mn_create')}>Start a Movie Night</GButton>
        </div>
      </div>
    </Screen>);

}

// Step header for movie-night flow
function NightHeader({ step, title }) {
  return (
    <>
      <TopSafe />
      <div style={{ padding: '2px 20px 6px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div onClick={() => back()} style={{ width: 38, height: 38, borderRadius: 12, background: T.surface, border: `1px solid ${T.line}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="chevL" size={20} c={T.text} /></div>
        <div style={{ display: 'flex', gap: 6, flex: 1 }}>
          {[0, 1, 2, 3].map((i) => <div key={i} style={{ flex: 1, height: 4, borderRadius: 9,
            background: i <= step ? 'transparent' : T.surface, backgroundImage: i <= step ? T.grad : 'none' }} />)}
        </div>
      </div>
      <div style={{ padding: '14px 20px 16px' }}>
        <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 12.5, color: T.red, letterSpacing: 0.4, textTransform: 'uppercase' }}>Movie Night · Step {step + 1}</div>
        <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 25, letterSpacing: -0.6, color: T.text, marginTop: 4 }}>{title}</div>
      </div>
    </>);

}

// ── MN Step 1: Create ──
function NightCreateScreen() {
  const sel = new Set(['@leop', '@sana', '@nadiar']);
  return (
    <Screen>
      <NightHeader step={0} title="Who's in tonight?" />
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 20px 100px' }}>
        {/* selected pills */}
        <div style={{ display: 'flex', gap: 14, overflow: 'hidden', paddingBottom: 18 }}>
          {FRIENDS.filter((f) => sel.has(f.handle)).map((f, i) =>
          <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, width: 58 }}>
              <div style={{ position: 'relative' }}>
                <Avatar person={f} size={54} />
                <div style={{ position: 'absolute', top: -2, right: -2, width: 20, height: 20, borderRadius: '50%', background: T.red,
                border: `2px solid ${T.bg}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="x" size={11} c="#fff" sw={3} /></div>
              </div>
              <span style={{ fontFamily: T.ui, fontSize: 11, color: T.sub, fontWeight: 600 }}>{f.name.split(' ')[0]}</span>
            </div>
          )}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, width: 58 }}>
            <div style={{ width: 54, height: 54, borderRadius: '50%', background: T.surface, border: `1.5px dashed ${T.line2}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="plus" size={22} c={T.sub} /></div>
            <span style={{ fontFamily: T.ui, fontSize: 11, color: T.faint }}>Add</span>
          </div>
        </div>
        {/* friend list to pick */}
        <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 12.5, color: T.faint, marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.3 }}>Suggested</div>
        {FRIENDS.slice(0, 5).map((f, i) => {
          const on = sel.has(f.handle);
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '9px 0' }}>
              <Avatar person={f} size={42} />
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 14.5, color: T.text }}>{f.name}</div>
                <div style={{ fontFamily: T.ui, fontSize: 11.5, color: T.faint }}>{f.on ? 'Online now' : 'Last seen 2h ago'}</div>
              </div>
              <div style={{ width: 26, height: 26, borderRadius: '50%', border: `2px solid ${on ? 'transparent' : T.line2}`,
                background: on ? 'transparent' : 'transparent', backgroundImage: on ? T.grad : 'none',
                display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {on && <Ic name="check" size={15} c="#fff" sw={3} />}</div>
            </div>);

        })}
        {/* filters */}
        <div style={{ marginTop: 14, padding: '14px 16px', borderRadius: 16, background: T.surface, border: `1px solid ${T.line}` }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}><Ic name="sliders" size={18} c={T.sub} />
              <span style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 14, color: T.text }}>Filters</span></div>
            <span style={{ fontFamily: T.ui, fontSize: 12.5, color: T.faint }}>Sci-Fi · Under 2½h</span>
          </div>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 20, right: 20, bottom: 24, zIndex: 45 }}>
        <GButton full icon="arrow" onClick={() => go('mn_wait')}>Create session · 3 invited</GButton>
      </div>
    </Screen>);

}

// ── MN Step 2: Waiting room ──
function NightWaitScreen() {
  const party = [ME, FRIENDS[0], FRIENDS[1], FRIENDS[3]];
  const joined = [true, true, false, true];
  return (
    <Screen>
      <NightHeader step={1} title="Waiting room" />
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 20px 100px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ borderRadius: 20, background: T.gradSoft, border: `1px solid ${T.line2}`, padding: '16px 18px', marginBottom: 20,
          display: 'flex', alignItems: 'center', gap: 13 }}>
          <div style={{ width: 46, height: 46, borderRadius: 14, background: T.grad, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ic name="film" size={24} c="#fff" /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 16, color: T.text }}>Friday Sci-Fi Night</div>
            <div style={{ fontFamily: T.ui, fontSize: 12.5, color: T.sub, marginTop: 1 }}>24 films queued · invite code <b style={{ color: T.text }}>MOON-42</b></div>
          </div>
        </div>
        <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 12.5, color: T.faint, marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.3 }}>
          3 of 4 joined</div>
        {party.map((p, i) =>
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '11px 0', borderBottom: `1px solid ${T.line}` }}>
            <Avatar person={p} size={46} />
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 15, color: T.text }}>{i === 0 ? 'You' : p.name} {i === 0 && <span style={{ fontSize: 11, color: T.gold, fontWeight: 700 }}>· Host</span>}</div>
              <div style={{ fontFamily: T.ui, fontSize: 12, color: T.faint }}>{p.handle}</div>
            </div>
            {joined[i] ?
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '7px 12px', borderRadius: 999, background: hexA(T.green, 0.14),
            fontFamily: T.ui, fontWeight: 700, fontSize: 12, color: T.green }}><Ic name="check" size={14} c={T.green} sw={2.6} />Ready</div> :

          <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '7px 12px', borderRadius: 999, background: T.surface,
            border: `1px solid ${T.line}`, fontFamily: T.ui, fontWeight: 600, fontSize: 12, color: T.faint }}>
                <span style={{ width: 7, height: 7, borderRadius: '50%', background: T.gold }} />Joining…</div>
          }
          </div>
        )}
      </div>
      <div style={{ position: 'absolute', left: 20, right: 20, bottom: 24, zIndex: 45 }}>
        <GButton full icon="play" onClick={() => go('mn_vote')}>Start voting now</GButton>
        <div style={{ textAlign: 'center', fontFamily: T.ui, fontSize: 12.5, color: T.faint, marginTop: 12 }}>You can start before everyone's in</div>
      </div>
    </Screen>);

}

// ── MN Step 3: Voting ──
function NightVoteScreen() {
  const m = byId('inter');
  const party = [ME, FRIENDS[0], FRIENDS[1], FRIENDS[3]];
  const done = [false, true, true, false];
  return (
    <Screen bg="#000">
      {/* full-bleed poster */}
      <div style={{ position: 'absolute', inset: 0, background: `linear-gradient(155deg, ${m.c1} 0%, ${m.c2} 90%)` }} />
      {POSTERS[m.id] &&
      <img src={POSTERS[m.id]} alt={m.t} onError={(e) => {e.currentTarget.style.display = 'none';}}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 230, background: 'linear-gradient(to bottom, rgba(0,0,0,0.72) 0%, transparent 100%)' }} />
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.92) 0%, rgba(0,0,0,0.5) 24%, rgba(0,0,0,0.12) 42%, transparent 58%)' }} />

      {/* live status (over poster) */}
      <TopSafe />
      <div style={{ position: 'absolute', top: 58, left: 0, right: 0, padding: '2px 20px 0', zIndex: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 20, color: '#fff', whiteSpace: 'nowrap', textShadow: '0 2px 12px rgba(0,0,0,0.5)' }}>Vote together</div>
          <div style={{ padding: '6px 12px', borderRadius: 999, background: 'rgba(255,255,255,0.18)', backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
            border: '1px solid rgba(255,255,255,0.28)', fontFamily: T.ui, fontWeight: 700, fontSize: 12, color: '#fff' }}>6 / 24</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {party.map((p, i) =>
          <div key={i} style={{ position: 'relative' }}>
              <div style={{ opacity: done[i] ? 1 : 0.45 }}><Avatar person={p} size={32} /></div>
              {done[i] && <div style={{ position: 'absolute', bottom: -2, right: -2, width: 14, height: 14, borderRadius: '50%', background: T.green,
              border: '2px solid #000', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic name="check" size={9} c="#fff" sw={3.5} /></div>}
            </div>
          )}
          <span style={{ fontFamily: T.ui, fontSize: 12, color: 'rgba(255,255,255,0.78)', marginLeft: 4 }}>2 of 4 finished voting</span>
        </div>
      </div>

      {/* meta */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 152, padding: '0 24px', zIndex: 6, pointerEvents: 'none' }}>
        <div style={{ display: 'flex', gap: 7, marginBottom: 12 }}>
          {m.g.map((g) => <span key={g} style={{ padding: '5px 12px', borderRadius: 999, background: 'rgba(255,255,255,0.18)',
            backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.22)',
            fontFamily: T.ui, fontWeight: 700, fontSize: 11.5, color: '#fff' }}>{g}</span>)}
        </div>
        <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 35, color: '#fff', letterSpacing: -0.7, lineHeight: 1.0, textShadow: '0 3px 18px rgba(0,0,0,0.55)' }}>{m.t}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 11, fontFamily: T.ui, fontSize: 13.5, color: 'rgba(255,255,255,0.9)', fontWeight: 600 }}>
          <span>{m.y}</span><span style={{ opacity: 0.5 }}>·</span><span>{runtime(m.m)}</span><span style={{ opacity: 0.5 }}>·</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Ic name="star" size={14} c={T.gold} /><span style={{ fontWeight: 700, color: '#fff' }}>{m.r.toFixed(1)}</span></span>
        </div>
      </div>

      {/* like/dislike buttons */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 34, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 28, zIndex: 8 }}>
        <div onClick={() => go('mn_result')} style={{ width: 66, height: 66, borderRadius: '50%', background: T.surface, border: `1px solid ${T.line2}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 12px 26px -8px ${hexA(T.red, 0.5)}` }}><Ic name="x" size={30} c={T.red} sw={2.4} /></div>
        <div onClick={() => go('mn_result')} style={{ width: 66, height: 66, borderRadius: '50%', background: T.surface, border: `1px solid ${T.line2}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 12px 26px -8px ${hexA(T.green, 0.6)}` }}>
          <Ic name="heartF" size={30} c={T.green} /></div>
      </div>
    </Screen>);

}

// ── MN Step 4: Results ──
function NightResultScreen() {
  const m = byId('inter');
  const likers = [ME, FRIENDS[0], FRIENDS[1], FRIENDS[3]];
  return (
    <Screen>
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        <TopSafe />
        <div style={{ textAlign: 'center', padding: '4px 24px 18px' }}>
          <div style={{ fontFamily: T.ui, fontWeight: 800, fontSize: 12.5, color: T.red, letterSpacing: 0.6, textTransform: 'uppercase' }}>It's a match</div>
          <div style={{ fontFamily: T.disp, fontWeight: 800, fontSize: 27, letterSpacing: -0.6, color: T.text, marginTop: 4 }}>Tonight you're watching</div>
        </div>
        {/* winner poster */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '0 0 18px' }}>
          <div style={{ position: 'relative' }}>
            <Poster m={m} w={186} r={20} />
            <div style={{ position: 'absolute', top: -12, right: -12, zIndex: 3, padding: '9px 13px', borderRadius: 14, background: T.grad,
                fontFamily: T.disp, fontWeight: 800, fontSize: 15, color: '#fff', boxShadow: '0 10px 22px -8px rgba(139,108,255,0.7)',
                transform: 'rotate(6deg)' }}>4 / 4 ♥</div>
          </div>
        </div>
        {/* meta */}
        <div style={{ textAlign: 'center', padding: '0 24px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, fontFamily: T.ui, fontSize: 13, color: T.sub, fontWeight: 600 }}>
            <span>{m.y}</span><span>·</span><span>{runtime(m.m)}</span><span>·</span><Stars r={m.r} size={13} /></div>
        </div>
        {/* likers */}
        <div style={{ margin: '0 20px 20px', padding: '14px 16px', borderRadius: 18, background: T.surface, border: `1px solid ${T.line}` }}>
          <div style={{ fontFamily: T.ui, fontWeight: 700, fontSize: 12.5, color: T.faint, marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.3 }}>Everyone loved it</div>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div style={{ display: 'flex', flex: 1 }}>{likers.map((p, i) => <div key={i} style={{ marginLeft: i ? -10 : 0 }}><Avatar person={p} size={40} ring /></div>)}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: T.ui, fontWeight: 700, fontSize: 13, color: T.green }}>
              <Ic name="heartF" size={16} c={T.green} />Unanimous</div>
          </div>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ padding: '0 20px 26px', display: 'flex', flexDirection: 'column', gap: 11 }}>
          <GButton full icon="play" onClick={() => go('detail')}>View details</GButton>
          <SButton full icon="undo" onClick={() => resetTo('mn_create')}>Start over</SButton>
        </div>
      </div>
    </Screen>);

}

Object.assign(window, { FriendsScreen, NightCreateScreen, NightWaitScreen, NightVoteScreen, NightResultScreen });