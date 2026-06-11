// ag-extra.jsx — feature screens from the real Agreeo app, in the Agreeo mockup style
// Mood Matcher (sheet), Mood Results, Random Pick (modal), Friend Profile
// Reuses tokens + components from ag-shared.

// Faint Home backdrop behind sheets/modals
function DimBackdrop({ scrim = 0.62 }) {
  const recs = ['dune2','inter','para','eeaao'];
  return (
    <>
      <div style={{ position:'absolute', inset:0, background:T.bg }} />
      <div style={{ position:'absolute', inset:0, filter:'blur(1.5px)', opacity:0.5 }}>
        <TopSafe />
        <div style={{ padding:'4px 20px 14px' }}>
          <div style={{ fontFamily:T.ui, fontSize:13, color:T.faint, fontWeight:600 }}>Friday night, Maya</div>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:25, color:T.text, whiteSpace:'nowrap' }}>What's the move?</div>
        </div>
        <div style={{ display:'flex', gap:14, padding:'8px 20px' }}>
          {recs.map(id => <Poster key={id} m={byId(id)} w={120} />)}
        </div>
      </div>
      <div onClick={()=>back()} style={{ position:'absolute', inset:0, background:`rgba(6,4,10,${scrim})`, cursor:'pointer' }} />
    </>
  );
}

function MField({ label, value }) {
  return (
    <div style={{ marginBottom:14 }}>
      <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:13, color:T.text, marginBottom:7 }}>{label}</div>
      <div style={{ minHeight:48, borderRadius:13, background:T.surface, border:`1px solid ${T.line}`,
        display:'flex', alignItems:'center', padding:'10px 14px',
        fontFamily:T.ui, fontSize:14, color: value?T.text:T.faint, fontWeight:value?600:500, lineHeight:1.4 }}>
        {value || 'Describe the vibe…'}
      </div>
    </div>
  );
}

const MOODS = ['Romantic','Stressed','Tired','Bored','Sad','Spooky'];

// ── Mood Matcher — input ──
function MoodMatcherScreen() {
  return (
    <Screen>
      <DimBackdrop />
      <div style={{ position:'absolute', left:0, right:0, bottom:0, height:'84%', background:T.bg2,
        borderTopLeftRadius:30, borderTopRightRadius:30, border:`1px solid ${T.line2}`, borderBottom:'none',
        boxShadow:'0 -20px 50px -16px rgba(0,0,0,0.6)', overflow:'hidden', display:'flex', flexDirection:'column' }}>
        <div style={{ display:'flex', justifyContent:'center', paddingTop:11 }}>
          <div style={{ width:44, height:5, borderRadius:9, background:T.line2 }} /></div>
        <div style={{ padding:'16px 22px 0', overflow:'hidden' }}>
          <div style={{ display:'flex', alignItems:'center', gap:11 }}>
            <div style={{ width:44, height:44, borderRadius:14, background:T.gradSoft, border:`1px solid ${T.line2}`,
              display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="sparkle" size={24} c={T.red} /></div>
            <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:23, letterSpacing:-0.5, color:T.text, whiteSpace:'nowrap' }}>Mood Matcher</div>
          </div>
          <div style={{ fontFamily:T.ui, fontSize:13, color:T.sub, marginTop:10, lineHeight:1.45 }}>
            On-device neural tag-embeddings read how you feel and match it to films.</div>

          <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:T.faint, margin:'20px 0 10px', textTransform:'uppercase', letterSpacing:0.3 }}>Quick vibes</div>
          <div style={{ display:'flex', gap:8, overflow:'hidden', marginBottom:22 }}>
            {MOODS.map(m => <Chip key={m} active={m==='Romantic'} icon={m==='Romantic'?'heartF':undefined}>{m}</Chip>)}
          </div>

          <MField label="How do you feel right now?" value="sentimental" />
          <MField label="How do you want to feel after the movie?" value="romantic, moved, and warm" />
          <GButton full icon="sparkle" style={{ marginTop:6 }} onClick={()=>go('moodloading')}>Match my mood</GButton>
        </div>
      </div>
    </Screen>
  );
}

// ── Mood Matcher — results ──
function MoodResultsScreen() {
  const matches = ['lala','past','portrait','gbh','eeaao'];
  return (
    <Screen>
      <DimBackdrop />
      <div style={{ position:'absolute', left:0, right:0, bottom:0, height:'84%', background:T.bg2,
        borderTopLeftRadius:30, borderTopRightRadius:30, border:`1px solid ${T.line2}`, borderBottom:'none',
        boxShadow:'0 -20px 50px -16px rgba(0,0,0,0.6)', overflow:'hidden', display:'flex', flexDirection:'column' }}>
        <div style={{ display:'flex', justifyContent:'center', paddingTop:11 }}>
          <div style={{ width:44, height:5, borderRadius:9, background:T.line2 }} /></div>
        <div style={{ padding:'16px 22px 0', overflow:'hidden' }}>
          <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between' }}>
            <div style={{ display:'flex', alignItems:'center', gap:11 }}>
              <div style={{ width:40, height:40, borderRadius:13, background:T.gradSoft, border:`1px solid ${T.line2}`,
                display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="sparkle" size={22} c={T.red} /></div>
              <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:21, letterSpacing:-0.4, color:T.text, whiteSpace:'nowrap' }}>Mood Matcher</div>
            </div>
            <div onClick={()=>back()} style={{ width:38, height:38, borderRadius:11, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
              display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="undo" size={18} c={T.sub} /></div>
          </div>

          <div style={{ display:'flex', alignItems:'flex-end', justifyContent:'space-between', margin:'26px 0 14px' }}>
            <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:18, color:T.text }}>Your vibe matches</div>
            <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:T.gold, whiteSpace:'nowrap' }}>12 titles found</div>
          </div>
          <div style={{ display:'flex', gap:14, overflow:'hidden', marginBottom:24 }}>
            {matches.map(id => { const m=byId(id); return (
              <div key={id} style={{ width:128 }} {...tap('detail')}>
                <Poster m={m} w={128} />
                <div style={{ fontFamily:T.ui, fontSize:12, color:T.faint, marginTop:8 }}>{m.y}</div>
              </div>
            ); })}
          </div>
          <div onClick={()=>go('mood')} style={{ padding:'13px 0', borderRadius:14, background:T.surface, border:`1px solid ${T.line2}`, cursor:'pointer',
            display:'flex', alignItems:'center', justifyContent:'center', gap:9,
            fontFamily:T.ui, fontWeight:700, fontSize:14.5, color:T.text }}>
            <Ic name="chevL" size={18} c={T.text} />Adjust vibe inputs</div>
        </div>
      </div>
    </Screen>
  );
}

// ── Random Pick — result modal ──
function RandomPickScreen() {
  const m = byId('gbh');
  return (
    <Screen>
      <DimBackdrop scrim={0.72} />
      <div style={{ position:'absolute', inset:0, display:'flex', alignItems:'center', justifyContent:'center', padding:'0 22px' }}>
        <div style={{ width:'100%', background:T.bg2, borderRadius:28, border:`1px solid ${T.line2}`, padding:'22px 22px 24px',
          boxShadow:'0 30px 60px -20px rgba(0,0,0,0.7)' }}>
          <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:18 }}>
            <div style={{ display:'flex', alignItems:'center', gap:10 }}>
              <div style={{ width:38, height:38, borderRadius:12, background:T.gradSoft, border:`1px solid ${T.line2}`,
                display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="dice" size={22} c={T.gold} /></div>
              <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:19, letterSpacing:-0.4, color:T.text, whiteSpace:'nowrap' }}>Your random pick</div>
            </div>
            <div onClick={()=>back()} style={{ width:34, height:34, borderRadius:10, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
              display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="x" size={17} c={T.sub} /></div>
          </div>
          <div style={{ display:'flex', justifyContent:'center', marginBottom:18 }}>
            <Poster m={m} w={172} r={18} />
          </div>
          <div style={{ textAlign:'center' }}>
            <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:21, letterSpacing:-0.4, color:T.text, lineHeight:1.1 }}>{m.t}</div>
            <div style={{ display:'flex', alignItems:'center', justifyContent:'center', gap:10, marginTop:9, fontFamily:T.ui, fontSize:12.5, color:T.sub, fontWeight:600 }}>
              <span>{m.y}</span><span>·</span><span>{runtime(m.m)}</span><span>·</span><Stars r={m.r} size={12} />
            </div>
            <div style={{ display:'flex', gap:7, justifyContent:'center', marginTop:12 }}>
              {m.g.map(g => <span key={g} style={{ padding:'5px 11px', borderRadius:999, background:T.surface, border:`1px solid ${T.line}`,
                fontFamily:T.ui, fontWeight:600, fontSize:11.5, color:T.sub }}>{g}</span>)}
            </div>
          </div>
          <div style={{ display:'flex', gap:11, marginTop:22 }}>
            <SButton icon="undo" style={{ flex:1, height:50 }}>Try again</SButton>
            <GButton icon="play" style={{ flex:1, height:50 }} onClick={()=>go('detail')}>Details</GButton>
          </div>
        </div>
      </div>
    </Screen>
  );
}

// ── Friend Profile (tab: watched | reviews | watchlist) ──
function FriendProfileScreen({ tab = 'watched' }) {
  const f = FRIENDS[0]; // Leo Park
  const stat = (icon, val, label, c) => (
    <div style={{ flex:1, padding:'12px 8px', borderRadius:16, background:hexA(c,0.10), border:`1px solid ${hexA(c,0.18)}`,
      display:'flex', flexDirection:'column', alignItems:'center', gap:5 }}>
      <Ic name={icon} size={18} c={c} />
      <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:19, color:T.text }}>{val}</div>
      <div style={{ fontFamily:T.ui, fontSize:11, color:T.faint, fontWeight:600 }}>{label}</div>
    </div>
  );
  const watched = ['inter','para','whip','madmax','br2049','arriv'];
  return (
    <Screen>
      <div style={{ flex:1, overflow:'hidden' }}>
        <TopSafe />
        {/* top bar */}
        <div style={{ padding:'2px 16px 6px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
          <div onClick={()=>back()} style={{ width:40, height:40, borderRadius:12, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
            display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="chevL" size={20} c={T.text} /></div>
          <div style={{ width:40, height:40, borderRadius:12, background:T.surface, border:`1px solid ${T.line}`,
            display:'flex', alignItems:'center', justifyContent:'center' }}>
            <div style={{ display:'flex', flexDirection:'column', gap:3 }}>
              {[0,1,2].map(i => <div key={i} style={{ width:4, height:4, borderRadius:9, background:T.sub }} />)}
            </div></div>
        </div>
        {/* header card */}
        <div style={{ margin:'8px 20px 0', borderRadius:26, background:T.gradSoft, border:`1px solid ${T.line2}`, padding:'18px 18px' }}>
          <div style={{ display:'flex', gap:16, alignItems:'center' }}>
            <Avatar person={f} size={68} />
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:21, letterSpacing:-0.4, color:T.text }}>{f.name}</div>
              <div style={{ fontFamily:T.ui, fontSize:12.5, color:T.sub, marginTop:3, lineHeight:1.4 }}>Thriller obsessive. Owns every Villeneuve on disc.</div>
              <div style={{ display:'inline-flex', alignItems:'center', gap:5, marginTop:7 }}>
                <Ic name="users" size={13} c={T.faint} /><span style={{ fontFamily:T.ui, fontSize:11.5, fontWeight:700, color:T.faint }}>Friends · {f.handle}</span>
              </div>
            </div>
          </div>
          <div style={{ display:'flex', gap:9, marginTop:16 }}>
            {stat('eye', f.watched, 'Watched', T.text)}
            {stat('edit', f.reviews, 'Reviews', T.gold)}
            {stat('film', 6, 'Nights', T.red)}
          </div>
        </div>
        {/* movie night action */}
        <div style={{ padding:'14px 20px 4px' }}>
          <GButton full icon="film" onClick={()=>go('mn_create')}>Start a Movie Night</GButton>
        </div>
        {/* tabs */}
        <div style={{ display:'flex', gap:24, padding:'14px 24px 0', borderBottom:`1px solid ${T.line}` }}>
          {[['Watched','watched'],['Reviews','reviews'],['Watchlist','watchlist']].map(([t,key]) => {
            const on = tab===key;
            const dest = key==='watched'?'friendp':key==='reviews'?'friendp_r':'friendp_x';
            return (
              <div key={t} onClick={()=>go(dest)} style={{ paddingBottom:11, position:'relative', cursor:'pointer',
                fontFamily:T.ui, fontWeight:on?800:600, fontSize:14, color:on?T.text:T.faint }}>
                {t}
                {on && <div style={{ position:'absolute', left:0, right:0, bottom:-1, height:2.5, borderRadius:9, background:T.red }} />}
              </div>
            );
          })}
        </div>
        {/* body */}
        {tab==='watched' && (
          <div style={{ padding:'16px 20px 30px', display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:11 }}>
            {watched.map(id => <div key={id} {...tap('detail')}><Poster m={byId(id)} w={104} r={12} showTitle={false} /></div>)}
          </div>
        )}
        {tab==='reviews' && (
          <div style={{ padding:'14px 20px 30px', display:'flex', flexDirection:'column', gap:11 }}>
            <FriendReview id="inter" rating={5} date="2 weeks ago" text="The docking scene alone is worth the runtime. Villeneuve-level patience." />
            <FriendReview id="br2049" rating={4} date="1 month ago" text="A slow, gorgeous machine. The sound design lives in my head rent-free." />
            <FriendReview id="madmax" rating={5} date="2 months ago" text="Two hours of pure kinetic poetry. Still the action benchmark." />
          </div>
        )}
        {tab==='watchlist' && (
          <div style={{ padding:'52px 34px', display:'flex', flexDirection:'column', alignItems:'center', textAlign:'center' }}>
            <div style={{ width:64, height:64, borderRadius:'50%', background:T.surface, border:`1px solid ${T.line2}`,
              display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="bookmark" size={28} c={T.faint} /></div>
            <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:17, color:T.text, marginTop:16 }}>Private section</div>
            <div style={{ fontFamily:T.ui, fontSize:13.5, color:T.sub, marginTop:7, lineHeight:1.5, maxWidth:260 }}>
              {f.name.split(' ')[0]}'s watchlist is private. Become closer friends to unlock it.</div>
          </div>
        )}
      </div>
    </Screen>
  );
}

function FriendReview({ id, rating, date, text }) {
  const m = byId(id);
  return (
    <div style={{ display:'flex', gap:13, padding:'13px 14px', borderRadius:18, background:T.surface, border:`1px solid ${T.line}` }}>
      <Poster m={m} w={50} r={9} showTitle={false} />
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:14.5, color:T.text }}>{m.t}</div>
        <div style={{ display:'flex', alignItems:'center', gap:8, margin:'5px 0 7px' }}>
          <div style={{ display:'flex', gap:1.5 }}>{[1,2,3,4,5].map(i => <Ic key={i} name="star" size={12} c={i<=rating?T.gold:T.line2} />)}</div>
          <span style={{ fontFamily:T.ui, fontSize:11, color:T.faint }}>{date}</span>
        </div>
        <div style={{ fontFamily:T.ui, fontSize:12.5, color:T.sub, fontStyle:'italic', lineHeight:1.45 }}>“{text}”</div>
      </div>
    </div>
  );
}

// ── Mood Matcher — loading ──
function MoodLoadingScreen() {
  return (
    <Screen>
      <DimBackdrop />
      <div style={{ position:'absolute', left:0, right:0, bottom:0, height:'84%', background:T.bg2,
        borderTopLeftRadius:30, borderTopRightRadius:30, border:`1px solid ${T.line2}`, borderBottom:'none',
        boxShadow:'0 -20px 50px -16px rgba(0,0,0,0.6)', overflow:'hidden', display:'flex', flexDirection:'column' }}>
        <div style={{ display:'flex', justifyContent:'center', paddingTop:11 }}>
          <div style={{ width:44, height:5, borderRadius:9, background:T.line2 }} /></div>
        <div style={{ padding:'16px 22px 0' }}>
          <div style={{ display:'flex', alignItems:'center', gap:11 }}>
            <div style={{ width:44, height:44, borderRadius:14, background:T.gradSoft, border:`1px solid ${T.line2}`,
              display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="sparkle" size={24} c={T.red} /></div>
            <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:23, letterSpacing:-0.5, color:T.text, whiteSpace:'nowrap' }}>Mood Matcher</div>
          </div>
        </div>
        <div style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:22, padding:'0 30px 60px' }}>
          <div style={{ width:58, height:58, borderRadius:'50%', border:`4px solid ${T.line2}`,
            borderTopColor:T.gold, borderRightColor:T.gold, transform:'rotate(35deg)' }} />
          <div style={{ textAlign:'center' }}>
            <div style={{ fontFamily:T.ui, fontWeight:700, fontSize:14.5, color:T.text }}>Running local transformer model…</div>
            <div style={{ fontFamily:T.ui, fontSize:12.5, color:T.faint, marginTop:6 }}>Comparing tags to find your vibe…</div>
          </div>
        </div>
      </div>
    </Screen>
  );
}

Object.assign(window, { MoodMatcherScreen, MoodResultsScreen, MoodLoadingScreen, RandomPickScreen, FriendProfileScreen });
