// ag-states.jsx — features that exist in the real app without a mockup yet:
// App splash/loading (bootstrap gate), Filters sheet, Review editor sheet.
// Reuses tokens + components from ag-shared, DimBackdrop from ag-extra.

// ── App Splash / Loading (bootstrap gate) ──
function SplashScreen() {
  return (
    <Screen bg={T.bg} style={{ alignItems:'center', justifyContent:'center' }}>
      {/* cinematic vertical wash */}
      <div style={{ position:'absolute', inset:0,
        background:`linear-gradient(180deg, ${T.bg} 0%, ${T.bg2} 55%, ${T.surface} 120%)` }} />
      <div style={{ position:'absolute', inset:0,
        background:`radial-gradient(90% 50% at 50% 38%, ${hexA(T.purple,0.16)} 0%, transparent 60%)` }} />
      <div style={{ position:'absolute', inset:0, opacity:0.05,
        backgroundImage:'repeating-linear-gradient(115deg,#fff 0 1px, transparent 1px 9px)' }} />

      <div style={{ position:'relative', display:'flex', flexDirection:'column', alignItems:'center', gap:0 }}>
        {/* logo mark */}
        <div style={{ width:88, height:88, borderRadius:28, background:T.grad,
          display:'flex', alignItems:'center', justifyContent:'center', marginBottom:26,
          boxShadow:`0 18px 44px -12px ${hexA(T.purple,0.65)}` }}>
          <div style={{ width:0, height:0, marginLeft:6,
            borderTop:'17px solid transparent', borderBottom:'17px solid transparent',
            borderLeft:'27px solid #fff' }} />
        </div>
        {/* wordmark */}
        <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:42, letterSpacing:-1.5, color:T.text, lineHeight:1 }}>Agreeo</div>
        <div style={{ fontFamily:T.ui, fontSize:14, color:T.sub, marginTop:11, fontWeight:600 }}>Agree on what to watch, faster.</div>
      </div>

      {/* loader pinned lower */}
      <div style={{ position:'absolute', left:0, right:0, bottom:78, display:'flex', flexDirection:'column', alignItems:'center', gap:14 }}>
        <div style={{ width:34, height:34, borderRadius:'50%', border:`3px solid ${T.line2}`,
          borderTopColor:T.red, borderRightColor:T.red, transform:'rotate(40deg)' }} />
        <div style={{ fontFamily:T.ui, fontSize:12.5, color:T.faint, fontWeight:600, letterSpacing:0.2 }}>Curating tonight's lineup…</div>
      </div>
    </Screen>
  );
}

// Reusable sheet shell (drag handle + rounded top), sits over a dimmed Home.
function Sheet({ height = '84%', children }) {
  return (
    <div style={{ position:'absolute', left:0, right:0, bottom:0, height, background:T.bg2,
      borderTopLeftRadius:30, borderTopRightRadius:30, border:`1px solid ${T.line2}`, borderBottom:'none',
      boxShadow:'0 -20px 50px -16px rgba(0,0,0,0.6)', overflow:'hidden', display:'flex', flexDirection:'column' }}>
      <div style={{ display:'flex', justifyContent:'center', paddingTop:11, flexShrink:0 }}>
        <div style={{ width:44, height:5, borderRadius:9, background:T.line2 }} />
      </div>
      {children}
    </div>
  );
}

// Selectable filter chip (matches the app's SelectableChip)
function FChip({ children, on }) {
  return (
    <span style={{ padding:'9px 15px', borderRadius:999, whiteSpace:'nowrap',
      fontFamily:T.ui, fontWeight:700, fontSize:13, letterSpacing:-0.1,
      color: on ? '#fff' : T.sub,
      background: on ? 'transparent' : T.surface,
      backgroundImage: on ? T.grad : 'none',
      border:`1px solid ${on ? 'transparent' : T.line}` }}>{children}</span>
  );
}

// ── Filters bottom sheet ──
function FilterSheetScreen() {
  const section = (title, chips) => (
    <div style={{ marginBottom:20 }}>
      <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:14.5, color:T.text, marginBottom:11 }}>{title}</div>
      <div style={{ display:'flex', flexWrap:'wrap', gap:9 }}>
        {chips.map(([label, on]) => <FChip key={label} on={on}>{label}</FChip>)}
      </div>
    </div>
  );
  return (
    <Screen>
      <DimBackdrop />
      <Sheet height="86%">
        <div style={{ flex:1, overflow:'hidden', padding:'16px 22px 0' }}>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:25, letterSpacing:-0.5, color:T.text }}>Filters</div>
          <div style={{ fontFamily:T.ui, fontSize:13, color:T.sub, marginTop:7, lineHeight:1.45, marginBottom:22 }}>
            Keep discovery fast by tightening only what matters tonight.</div>

          {section('Genre', [['Any',false],['Sci-Fi',true],['Drama',false],['Thriller',false],['Comedy',false],['Romance',false]])}
          {section('Max duration', [['Any',false],['90m',false],['120m',false],['150m',true]])}
          {section('From year', [['Any',true],['2015+',false],['2020+',false],['2023+',false]])}
          {section('Minimum rating', [['Any',false],['7.0+',false],['8.0+',true],['8.5+',false]])}
        </div>
        {/* actions */}
        <div style={{ flexShrink:0, padding:'14px 22px 26px', display:'flex', gap:12,
          borderTop:`1px solid ${T.line}`, background:T.bg2 }}>
          <SButton style={{ flex:1, height:50 }}>Reset</SButton>
          <GButton icon="check" style={{ flex:1.4, height:50 }} onClick={()=>back()}>Apply · 3 set</GButton>
        </div>
      </Sheet>
    </Screen>
  );
}

// ── Review editor sheet ──
function ReviewEditorScreen() {
  const m = byId('inter');
  const rating = 5;
  return (
    <Screen>
      <DimBackdrop scrim={0.66} />
      <Sheet height="78%">
        <div style={{ flex:1, overflow:'hidden', padding:'16px 22px 0' }}>
          {/* movie header */}
          <div style={{ display:'flex', gap:14, alignItems:'center', marginBottom:20 }}>
            <Poster m={m} w={56} r={11} showTitle={false} />
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:12, color:T.faint, textTransform:'uppercase', letterSpacing:0.4 }}>Your review</div>
              <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:20, letterSpacing:-0.4, color:T.text, marginTop:3, lineHeight:1.1 }}>{m.t}</div>
            </div>
          </div>

          {/* rating */}
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:14.5, color:T.text, marginBottom:10 }}>Your rating</div>
          <div style={{ display:'flex', gap:9, marginBottom:22 }}>
            {[1,2,3,4,5].map(i => <Ic key={i} name="star" size={34} c={i<=rating?T.gold:T.line2} />)}
          </div>

          {/* text field */}
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:14.5, color:T.text, marginBottom:10 }}>What stuck with you?</div>
          <div style={{ minHeight:118, borderRadius:16, background:T.surface, border:`1.5px solid ${hexA(T.red,0.4)}`,
            padding:'14px 16px', fontFamily:T.ui, fontSize:14.5, color:T.text, lineHeight:1.55 }}>
            Cried twice. The docking scene is unreal — a film that earns its three hours.<span style={{ display:'inline-block', width:2, height:18, background:T.red, marginLeft:2, verticalAlign:'-3px' }} /></div>
          <div style={{ fontFamily:T.ui, fontSize:11.5, color:T.faint, marginTop:8, textAlign:'right' }}>Keep it quick — you can always refine it later.</div>
        </div>
        {/* actions */}
        <div style={{ flexShrink:0, padding:'14px 22px 26px', display:'flex', gap:12,
          borderTop:`1px solid ${T.line}`, background:T.bg2 }}>
          <SButton icon="x" style={{ flex:1, height:50 }} onClick={()=>back()}>Delete</SButton>
          <GButton icon="check" style={{ flex:1.4, height:50 }} onClick={()=>back()}>Save review</GButton>
        </div>
      </Sheet>
    </Screen>
  );
}

// ── Reusable empty / error state (matches the app's EmptyState) ──
function EmptyState({ icon, title, message, actionLabel, actionIcon, onAction }) {
  return (
    <div style={{ alignSelf:'stretch', boxSizing:'border-box', borderRadius:28, background:hexA('#ffffff',0.04), border:`1px solid ${T.line}`,
      padding:'34px 26px', display:'flex', flexDirection:'column', alignItems:'center', textAlign:'center' }}>
      <div style={{ width:72, height:72, borderRadius:'50%', background:hexA(T.red,0.14), flexShrink:0,
        display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name={icon} size={32} c={T.red} /></div>
      <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:18, lineHeight:1.25, color:T.text, marginTop:20, letterSpacing:-0.3, textWrap:'balance' }}>{title}</div>
      <div style={{ fontFamily:T.ui, fontSize:13.5, color:T.sub, marginTop:9, lineHeight:1.5, maxWidth:280 }}>{message}</div>
      {actionLabel && (
        <div onClick={onAction} style={{ marginTop:20, display:'inline-flex', alignItems:'center', gap:8, padding:'12px 22px', borderRadius:14, whiteSpace:'nowrap', cursor:'pointer',
          background:T.grad, fontFamily:T.ui, fontWeight:800, fontSize:14, color:'#fff' }}>
          {actionIcon && <Ic name={actionIcon} size={18} c="#fff" sw={2.2} />}{actionLabel}</div>
      )}
    </div>
  );
}

// Library chrome shared by the empty + search states (mirrors LibraryScreen)
function LibChrome({ active = 'Watchlist', searchValue, counts = [0,58,212], children }) {
  return (
    <Screen>
      <BottomNav active="library" />
      <div style={{ flex:1, overflow:'hidden', display:'flex', flexDirection:'column' }}>
        <TopSafe />
        <div style={{ padding:'2px 20px 14px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:27, letterSpacing:-0.6, color:T.text, whiteSpace:'nowrap' }}>Your Library</div>
          <div style={{ width:42, height:42, borderRadius:13, background:T.surface, border:`1px solid ${T.line}`,
            display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="search" size={20} c={T.text} /></div>
        </div>
        {searchValue !== undefined && (
          <div style={{ padding:'0 20px 12px' }}>
            <div style={{ height:46, borderRadius:14, background:T.surface, border:`1.5px solid ${hexA(T.red,0.4)}`,
              display:'flex', alignItems:'center', gap:9, padding:'0 14px' }}>
              <Ic name="search" size={19} c={T.faint} />
              <span style={{ fontFamily:T.ui, fontSize:14.5, color:T.text, fontWeight:600 }}>{searchValue}</span>
              <div style={{ flex:1 }} />
              <Ic name="x" size={17} c={T.faint} />
            </div>
          </div>
        )}
        <div style={{ display:'flex', gap:6, margin:'0 20px 6px', padding:5, borderRadius:14, background:T.surface, border:`1px solid ${T.line}` }}>
          {[['Watchlist',counts[0]],['Liked',counts[1]],['Watched',counts[2]]].map(([t,n]) => {
            const on = t===active;
            return (
              <div key={t} style={{ flex:1, height:38, borderRadius:10, display:'flex', alignItems:'center', justifyContent:'center', gap:6,
                background: on ? T.grad : 'transparent', fontFamily:T.ui, fontWeight:700, fontSize:13.5, color: on?'#fff':T.sub }}>
                {t}<span style={{ fontSize:11, opacity:0.8 }}>{n}</span></div>
            );
          })}
        </div>
        <div style={{ flex:1, overflow:'hidden', padding:'18px 20px 0', display:'flex', flexDirection:'column' }}>
          {children}
        </div>
      </div>
    </Screen>
  );
}

// ── Library · Empty (watchlist) — real app copy ──
function LibraryEmptyScreen() {
  return (
    <LibChrome active="Watchlist" counts={[0,58,212]}>
      <div style={{ marginTop:24 }}>
        <EmptyState icon="bookmark" title="Your watchlist is empty."
          message="Save movies from Swipe or Home to find them here."
          actionLabel="Browse Home" actionIcon="home" onAction={()=>resetTo('home')} />
      </div>
    </LibChrome>
  );
}

// ── Search · No results ──
function SearchEmptyScreen() {
  return (
    <LibChrome active="Watchlist" searchValue="oppenhimer" counts={[14,58,212]}>
      <div style={{ marginTop:18 }}>
        <EmptyState icon="search" title="No matches found."
          message={'Nothing in your library matches “oppenhimer”. Check the spelling, or try a broader title or genre.'}
          actionLabel="Clear search" actionIcon="x" onAction={()=>back()} />
      </div>
    </LibChrome>
  );
}

// ── Connection error / Offline ──
function OfflineScreen() {
  return (
    <Screen style={{ alignItems:'center', justifyContent:'center', padding:'0 26px' }}>
      <TopSafe />
      <div style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', width:'100%' }}>
        <EmptyState icon="wifiOff" title="You're offline."
          message="We can't reach Agreeo right now. Your library is saved on this device — reconnect to sync your watchlist and Movie Nights."
          actionLabel="Try again" actionIcon="refresh" onAction={()=>resetTo('home')} />
        <div style={{ fontFamily:T.ui, fontSize:12, color:T.faint, marginTop:18 }}>Last synced 12 minutes ago</div>
      </div>
    </Screen>
  );
}

// ── Settings (the real app's Profile › Settings tab) ──
function Toggle({ on }) {
  return (
    <div style={{ width:48, height:29, borderRadius:999, flexShrink:0, padding:3, display:'flex',
      justifyContent: on ? 'flex-end' : 'flex-start',
      background: on ? 'transparent' : T.surface2, backgroundImage: on ? T.grad : 'none',
      border:`1px solid ${on ? 'transparent' : T.line2}`, transition:'all .2s' }}>
      <div style={{ width:23, height:23, borderRadius:'50%', background:'#fff', boxShadow:'0 2px 5px rgba(0,0,0,0.35)' }} />
    </div>
  );
}

function SettingsScreen() {
  const SectionTitle = ({ icon, title }) => (
    <div style={{ display:'flex', alignItems:'center', gap:9, margin:'0 0 9px' }}>
      <Ic name={icon} size={18} c={T.gold} />
      <span style={{ fontFamily:T.disp, fontWeight:800, fontSize:14.5, color:T.text, letterSpacing:-0.3 }}>{title}</span>
    </div>
  );
  const Card = ({ rows }) => (
    <div style={{ borderRadius:18, background:T.surface, border:`1px solid ${T.line}`, overflow:'hidden', marginBottom:16 }}>
      {rows.map((r,i) => (
        <div key={i} style={{ display:'flex', alignItems:'center', gap:13, padding:'11px 15px',
          borderTop: i ? `1px solid ${T.line}` : 'none' }}>
          <Ic name={r.icon} size={20} c={T.sub} />
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ fontFamily:T.ui, fontWeight:600, fontSize:13.5, color:T.text }}>{r.title}</div>
            {r.sub && <div style={{ fontFamily:T.ui, fontSize:11.5, color:T.faint, marginTop:1 }}>{r.sub}</div>}
          </div>
          {r.toggle !== undefined ? <Toggle on={r.toggle} /> : r.chevron ? <Ic name="chevron" size={18} c={T.faint} /> : null}
        </div>
      ))}
    </div>
  );
  return (
    <Screen>
      <div style={{ flex:1, overflow:'hidden', display:'flex', flexDirection:'column' }}>
        <TopSafe />
        <div style={{ padding:'2px 16px 12px', display:'flex', alignItems:'center', gap:12 }}>
          <div onClick={()=>back()} style={{ width:40, height:40, borderRadius:12, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
            display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="chevL" size={20} c={T.text} /></div>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:23, letterSpacing:-0.5, color:T.text }}>Settings</div>
        </div>
        <div style={{ flex:1, overflow:'auto', padding:'4px 20px 24px' }}>
          <SectionTitle icon="moon" title="Appearance" />
          <div style={{ display:'flex', gap:6, marginBottom:18, padding:5, borderRadius:16, background:T.surface, border:`1px solid ${T.line}` }}>
            {[['Light','bulb'],['Dark','moon']].map(([m,ic]) => {
              const isDark = (window.AGTHEME && window.AGTHEME.dark) || false;
              const on = (m==='Dark') === isDark;
              return (
                <div key={m} onClick={()=>{ const d=(window.AGTHEME&&window.AGTHEME.dark)||false; if ((m==='Dark')!==d && window.AGTHEME) window.AGTHEME.toggle(); }}
                  style={{ flex:1, height:42, borderRadius:12, display:'flex', alignItems:'center', justifyContent:'center', gap:8, cursor:'pointer',
                    background: on?T.grad:'transparent', color: on?'#fff':T.sub, fontFamily:T.ui, fontWeight:700, fontSize:14 }}>
                  <Ic name={ic} size={18} c={on?'#fff':T.sub} />{m}</div>
              );
            })}
          </div>
          <SectionTitle icon="shield" title="Privacy" />
          <Card rows={[
            { icon:'eye', title:'Show watched to friends', toggle:true },
            { icon:'heart', title:'Show liked to friends', toggle:true },
            { icon:'bookmark', title:'Show watchlist to friends', toggle:false },
            { icon:'edit', title:'Show reviews to friends', toggle:true },
          ]} />
          <SectionTitle icon="bell" title="Notifications" />
          <Card rows={[
            { icon:'bulb', title:'Daily suggestion reminder', toggle:false },
            { icon:'film', title:'Movie Night invites', toggle:true },
            { icon:'vote', title:'Voting started', toggle:true },
            { icon:'trophy', title:'Final decision reached', toggle:true },
          ]} />
          <SectionTitle icon="settings" title="Account" />
          <Card rows={[
            { icon:'mail', title:ME.handle.replace('@','')+'@agreeo.app', sub:'Member since Mar 2024' },
            { icon:'shield', title:'Privacy policy & terms', chevron:true },
          ]} />
          <SButton full icon="logout" style={{ color:T.red, borderColor:hexA(T.red,0.4), marginTop:4 }} onClick={()=>resetTo('login')}>Log out</SButton>
        </div>
      </div>
    </Screen>
  );
}

// ── Edit profile sheet ──
function EditProfileScreen() {
  return (
    <Screen>
      <DimBackdrop scrim={0.66} />
      <Sheet height="72%">
        <div style={{ flex:1, overflow:'hidden', padding:'16px 22px 0' }}>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:25, letterSpacing:-0.5, color:T.text, marginBottom:20 }}>Edit profile</div>
          {/* avatar */}
          <div style={{ display:'flex', justifyContent:'center', marginBottom:24 }}>
            <div style={{ position:'relative' }}>
              <Avatar person={ME} size={84} />
              <div style={{ position:'absolute', bottom:0, right:0, width:30, height:30, borderRadius:'50%', background:T.grad,
                border:`2.5px solid ${T.bg2}`, display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="edit" size={14} c="#fff" /></div>
            </div>
          </div>
          {/* display name */}
          <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:13, color:T.text, marginBottom:8 }}>Display name</div>
          <div style={{ height:50, borderRadius:14, background:T.surface, border:`1px solid ${T.line2}`, display:'flex', alignItems:'center',
            padding:'0 14px', marginBottom:18, fontFamily:T.ui, fontSize:15, color:T.text, fontWeight:600 }}>{ME.name}</div>
          {/* bio */}
          <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:13, color:T.text, marginBottom:8 }}>Bio / status</div>
          <div style={{ minHeight:96, borderRadius:14, background:T.surface, border:`1.5px solid ${hexA(T.red,0.4)}`, padding:'12px 14px',
            fontFamily:T.ui, fontSize:14, color:T.text, lineHeight:1.5 }}>
            Sci-fi devotee &amp; certified popcorn snob. Will absolutely make you watch the director's cut.<span style={{ display:'inline-block', width:2, height:17, background:T.red, marginLeft:1, verticalAlign:'-3px' }} /></div>
        </div>
        <div style={{ flexShrink:0, padding:'14px 22px 26px', borderTop:`1px solid ${T.line}`, background:T.bg2 }}>
          <GButton full icon="check" onClick={()=>back()}>Save profile</GButton>
        </div>
      </Sheet>
    </Screen>
  );
}

// ── Add friends sheet ──
function AddFriendsScreen() {
  const sugg = [FRIENDS[4], FRIENDS[2]];
  return (
    <Screen>
      <DimBackdrop scrim={0.6} />
      <Sheet height="74%">
        <div style={{ flex:1, overflow:'hidden', padding:'16px 22px 0' }}>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:25, letterSpacing:-0.5, color:T.text }}>Add friends</div>
          <div style={{ fontFamily:T.ui, fontSize:13, color:T.sub, marginTop:7, marginBottom:18, lineHeight:1.45 }}>
            Find people by username, or share your invite link.</div>
          {/* search field */}
          <div style={{ height:50, borderRadius:14, background:T.surface, border:`1.5px solid ${hexA(T.red,0.4)}`,
            display:'flex', alignItems:'center', gap:8, padding:'0 14px', marginBottom:14 }}>
            <Ic name="search" size={19} c={T.faint} />
            <span style={{ fontFamily:T.ui, fontSize:15, color:T.text, fontWeight:600 }}>@maya</span>
            <span style={{ display:'inline-block', width:2, height:18, background:T.red }} />
          </div>
          {/* share invite */}
          <div style={{ display:'flex', alignItems:'center', gap:13, padding:'13px 15px', borderRadius:16, marginBottom:22,
            background:T.gradSoft, border:`1px solid ${T.line2}`, cursor:'pointer' }}>
            <div style={{ width:42, height:42, borderRadius:12, background:T.grad, display:'flex', alignItems:'center', justifyContent:'center' }}>
              <Ic name="share" size={20} c="#fff" /></div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:14, color:T.text }}>Share invite link</div>
              <div style={{ fontFamily:T.ui, fontSize:12, color:T.faint, marginTop:1 }}>agreeo.app/u/mayao</div>
            </div>
            <Ic name="chevron" size={18} c={T.faint} />
          </div>
          <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:T.faint, marginBottom:10, textTransform:'uppercase', letterSpacing:0.3 }}>Suggested</div>
          {sugg.map((f,i) => (
            <div key={i} style={{ display:'flex', alignItems:'center', gap:13, padding:'9px 0' }}>
              <Avatar person={f} size={44} />
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:14.5, color:T.text }}>{f.name}</div>
                <div style={{ fontFamily:T.ui, fontSize:11.5, color:T.faint }}>{f.handle} · 3 mutual</div>
              </div>
              <div style={{ display:'inline-flex', alignItems:'center', gap:6, padding:'9px 16px', borderRadius:11, background:T.grad,
                fontFamily:T.ui, fontWeight:700, fontSize:13, color:'#fff' }}><Ic name="plus" size={15} c="#fff" sw={2.6} />Add</div>
            </div>
          ))}
        </div>
      </Sheet>
    </Screen>
  );
}

Object.assign(window, { SplashScreen, FilterSheetScreen, ReviewEditorScreen,
  EmptyState, LibraryEmptyScreen, SearchEmptyScreen, OfflineScreen, SettingsScreen, EditProfileScreen, AddFriendsScreen });
