// ag-auth.jsx — Authentication + Onboarding screens

// Branded wordmark
function Wordmark({ size = 30, c = T.text }) {
  return (
    <div style={{ display:'flex', alignItems:'center', gap:9 }}>
      <div style={{ width:size*1.12, height:size*1.12, borderRadius:size*0.34, background:T.grad,
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow:'0 6px 16px -4px rgba(139,108,255,0.6)' }}>
        <Ic name="play" size={size*0.5} c="#fff" />
      </div>
      <span style={{ fontFamily:T.disp, fontWeight:800, fontSize:size, letterSpacing:-0.8, color:c }}>Agreeo</span>
    </div>
  );
}

// Field
function Field({ label, value, ph, type, focused }) {
  return (
    <div style={{ marginBottom:14 }}>
      <div style={{ fontFamily:T.ui, fontWeight:600, fontSize:12.5, color:T.faint, marginBottom:7, paddingLeft:3 }}>{label}</div>
      <div style={{ height:54, borderRadius:14, background:T.surface, display:'flex', alignItems:'center', padding:'0 16px',
        border:`1.5px solid ${focused ? T.red : T.line}`, boxShadow: focused ? '0 0 0 4px rgba(255,93,84,0.12)' : 'none' }}>
        <span style={{ fontFamily:T.ui, fontWeight:value?600:500, fontSize:15.5,
          color: value ? T.text : T.faint, flex:1 }}>
          {value || ph}{type==='password' && value ? '' : ''}
        </span>
        {type==='password' && <Ic name="eye" size={19} c={T.faint} />}
      </div>
    </div>
  );
}

// Hero poster collage (fanned)
function PosterFan() {
  const picks = ['inter','dune2','para','eeaao','lala'];
  return (
    <div style={{ position:'absolute', top:-30, left:0, right:0, height:330, overflow:'hidden' }}>
      <div style={{ position:'absolute', inset:0, display:'flex', justifyContent:'center', gap:10, paddingTop:18, opacity:0.9,
        transform:'rotate(-9deg) scale(1.25)', transformOrigin:'top center' }}>
        {[0,1,2,3].map(col => (
          <div key={col} style={{ display:'flex', flexDirection:'column', gap:10, marginTop: col%2?28:0 }}>
            {[0,1].map(row => <Poster key={row} m={byId(picks[(col+row)%picks.length])} w={104} r={12} showTitle={false} />)}
          </div>
        ))}
      </div>
      <div style={{ position:'absolute', inset:0, background:`linear-gradient(to bottom, ${hexA(T.bg,0.2)} 0%, ${hexA(T.bg,0.7)} 55%, ${T.bg} 92%)` }} />
    </div>
  );
}

// ── 1. Login ──
function LoginScreen() {
  return (
    <Screen>
      <PosterFan />
      <div style={{ position:'relative', flex:1, display:'flex', flexDirection:'column', padding:'0 22px', justifyContent:'flex-end', paddingBottom:30 }}>
        <div style={{ marginBottom:22 }}>
          <Wordmark size={34} />
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:30, lineHeight:1.05, letterSpacing:-0.8, marginTop:20, color:T.text }}>
            Movie night,<br/>finally <span style={{ background:T.grad, WebkitBackgroundClip:'text', backgroundClip:'text', color:'transparent' }}>agreed.</span>
          </div>
          <div style={{ fontFamily:T.ui, fontSize:14.5, color:T.sub, marginTop:10, lineHeight:1.45 }}>
            Discover films, build your taste, and decide together — no more endless scrolling.
          </div>
        </div>
        <Field label="Email" value="maya@hey.com" ph="you@email.com" />
        <Field label="Password" value="••••••••••" ph="Password" type="password" focused />
        <div style={{ textAlign:'right', fontFamily:T.ui, fontWeight:600, fontSize:13, color:T.sub, margin:'2px 2px 18px' }}>Forgot password?</div>
        <GButton full icon="arrow" onClick={()=>go('home')}>Log in</GButton>
        <div style={{ textAlign:'center', fontFamily:T.ui, fontSize:13.5, color:T.faint, marginTop:18 }}>
          New here? <span {...tap('signup')} style={{ color:T.red, fontWeight:700, cursor:'pointer' }}>Create an account</span>
        </div>
      </div>
    </Screen>
  );
}

// ── 2. Sign up ──
function SignupScreen() {
  return (
    <Screen>
      <TopSafe />
      <div style={{ padding:'8px 22px 0', display:'flex', alignItems:'center', gap:14 }}>
        <div onClick={()=>back()} style={{ width:38, height:38, borderRadius:12, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
          display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="chevL" size={20} c={T.text} /></div>
        <div style={{ flex:1, height:5, borderRadius:9, background:T.surface, overflow:'hidden' }}>
          <div style={{ width:'33%', height:'100%', background:T.grad }} /></div>
        <span style={{ fontFamily:T.ui, fontWeight:700, fontSize:12, color:T.faint }}>1 / 3</span>
      </div>
      <div style={{ flex:1, padding:'26px 22px 0', display:'flex', flexDirection:'column' }}>
        <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:29, letterSpacing:-0.7, color:T.text, lineHeight:1.05 }}>Create your account</div>
        <div style={{ fontFamily:T.ui, fontSize:14, color:T.sub, marginTop:8, marginBottom:26 }}>It takes about a minute. We'll tune your taste next.</div>
        <Field label="Display name" value="Maya Okonkwo" ph="Your name" />
        <Field label="Email" value="maya@hey.com" ph="you@email.com" focused />
        <Field label="Password" value="" ph="At least 8 characters" type="password" />
        <div style={{ display:'flex', alignItems:'flex-start', gap:10, marginTop:6 }}>
          <div style={{ width:22, height:22, borderRadius:7, background:T.grad, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
            <Ic name="check" size={14} c="#fff" sw={2.6} /></div>
          <span style={{ fontFamily:T.ui, fontSize:12.5, color:T.sub, lineHeight:1.5 }}>I agree to the <span style={{ color:T.text, fontWeight:600 }}>Terms</span> & <span style={{ color:T.text, fontWeight:600 }}>Privacy Policy</span>.</span>
        </div>
        <div style={{ flex:1 }} />
        <GButton full icon="arrow" style={{ marginBottom:14 }} onClick={()=>go('ob_genres')}>Continue</GButton>
      </div>
    </Screen>
  );
}

// ── 3. Onboarding — Genres ──
function GenreScreen() {
  const picked = new Set(['Sci-Fi','Drama','Thriller','Romance','Animation']);
  return (
    <Screen>
      <TopSafe />
      <div style={{ padding:'8px 22px 0', display:'flex', alignItems:'center', gap:14 }}>
        <div style={{ flex:1, height:5, borderRadius:9, background:T.surface, overflow:'hidden' }}>
          <div style={{ width:'66%', height:'100%', background:T.grad }} /></div>
        <span style={{ fontFamily:T.ui, fontWeight:700, fontSize:12, color:T.faint }}>2 / 3</span>
      </div>
      <div style={{ padding:'24px 22px 14px' }}>
        <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:28, letterSpacing:-0.7, color:T.text, lineHeight:1.05 }}>What do you love<br/>to watch?</div>
        <div style={{ fontFamily:T.ui, fontSize:14, color:T.sub, marginTop:8 }}>Pick at least 3. This shapes your feed.</div>
      </div>
      <div style={{ flex:1, overflow:'hidden', padding:'0 18px', display:'flex', flexWrap:'wrap', gap:10, alignContent:'flex-start' }}>
        {ALL_GENRES.map(g => {
          const on = picked.has(g);
          return (
            <div key={g} style={{ padding:'12px 17px', borderRadius:14, fontFamily:T.ui, fontWeight:700, fontSize:14.5,
              color: on ? '#fff' : T.sub, background: on ? 'transparent' : T.surface,
              backgroundImage: on ? T.grad : 'none',
              border:`1.5px solid ${on ? 'transparent' : T.line}`,
              display:'flex', alignItems:'center', gap:8,
              boxShadow: on ? '0 8px 20px -8px rgba(139,108,255,0.55)' : 'none' }}>
              {on && <Ic name="check" size={15} c="#fff" sw={2.6} />}{g}
            </div>
          );
        })}
      </div>
      <div style={{ padding:'12px 22px 22px', background:`linear-gradient(to top, ${T.bg} 70%, transparent)` }}>
        <GButton full icon="arrow" onClick={()=>go('ob_fav')}>Continue · {picked.size} picked</GButton>
      </div>
    </Screen>
  );
}

// ── 4. Onboarding — Favorite movies ──
function CalibrateScreen() {
  const picked = new Set(['inter','para','eeaao','whip']);
  return (
    <Screen>
      <TopSafe />
      <div style={{ padding:'8px 22px 0', display:'flex', alignItems:'center', gap:14 }}>
        <div style={{ flex:1, height:5, borderRadius:9, background:T.surface, overflow:'hidden' }}>
          <div style={{ width:'100%', height:'100%', background:T.grad }} /></div>
        <span style={{ fontFamily:T.ui, fontWeight:700, fontSize:12, color:T.faint }}>3 / 3</span>
      </div>
      <div style={{ padding:'24px 22px 16px' }}>
        <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:28, letterSpacing:-0.7, color:T.text, lineHeight:1.05 }}>Tap a few you<br/>already love</div>
        <div style={{ fontFamily:T.ui, fontSize:14, color:T.sub, marginTop:8 }}>We'll calibrate your recommendations from these.</div>
      </div>
      <div style={{ flex:1, overflow:'hidden', padding:'0 18px' }}>
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:11, justifyItems:'center' }}>
          {MOVIES.slice(0,12).map(m => {
            const on = picked.has(m.id);
            return (
              <div key={m.id} style={{ position:'relative', borderRadius:12, overflow:'hidden',
                outline: on ? `2.5px solid ${T.red}` : 'none', outlineOffset:2 }}>
                <Poster m={m} w={104} r={12} showTitle={false} />
                {on && <div style={{ position:'absolute', inset:0, background:hexA(T.red,0.28),
                  display:'flex', alignItems:'center', justifyContent:'center' }}>
                  <div style={{ width:30, height:30, borderRadius:'50%', background:T.red, display:'flex', alignItems:'center', justifyContent:'center' }}>
                    <Ic name="check" size={18} c="#fff" sw={3} /></div></div>}
              </div>
            );
          })}
        </div>
      </div>
      <div style={{ padding:'12px 22px 22px', background:`linear-gradient(to top, ${T.bg} 70%, transparent)` }}>
        <GButton full icon="sparkle" onClick={()=>resetTo('home')}>Build my feed</GButton>
      </div>
    </Screen>
  );
}

Object.assign(window, { Wordmark, LoginScreen, SignupScreen, GenreScreen, CalibrateScreen });
