// ag-detail.jsx — Movie Details, Profile, Notifications

// ── Movie Details ──
function DetailScreen() {
  const m = byId('inter');
  const [st, setSt] = React.useState({ liked:true, watchlist:false, watched:true });
  const StateBtn = ({ icon, label, c, k }) => {
    const on = st[k];
    return (
    <div onClick={()=>setSt(s=>({ ...s, [k]: !s[k] }))} style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:7, padding:'13px 0', borderRadius:16, cursor:'pointer',
      background: on ? hexA(c,0.14) : T.surface, border:`1px solid ${on ? hexA(c,0.4) : T.line}` }}>
      <Ic name={icon} size={22} c={on ? c : T.sub} />
      <span style={{ fontFamily:T.ui, fontWeight:700, fontSize:11.5, color: on ? c : T.sub }}>{label}</span>
    </div>
    );
  };
  return (
    <Screen>
      <div style={{ flex:1, overflow:'hidden' }}>
        {/* backdrop hero */}
        <div style={{ position:'relative', height:340, flexShrink:0 }}>
          <div style={{ position:'absolute', inset:0, background:`linear-gradient(160deg, ${m.c1}, ${m.c2})` }} />
          {POSTERS[m.id] &&
          <img src={POSTERS[m.id]} alt={m.t} onError={(e)=>{e.currentTarget.style.display='none';}}
          style={{ position:'absolute', inset:0, width:'100%', height:'100%', objectFit:'cover', objectPosition:'center 22%' }} />}
          <div style={{ position:'absolute', inset:0, opacity:0.12, backgroundImage:'repeating-linear-gradient(115deg,#fff 0 1px, transparent 1px 8px)' }} />
          <div style={{ position:'absolute', inset:0, background:`linear-gradient(to bottom, ${hexA(T.heroBg,0.05)} 0%, ${hexA(T.heroBg,0.45)} 50%, ${T.heroBg} 99%)` }} />
          <TopSafe />
          {/* nav buttons */}
          <div style={{ position:'absolute', top:58, left:18, right:18, display:'flex', justifyContent:'space-between', zIndex:5 }}>
            {['chevL','heart'].map((ic,i) => (
              <div key={i} onClick={i===0?()=>back():undefined} style={{ width:42, height:42, borderRadius:13, background:'rgba(20,17,27,0.55)', backdropFilter:'blur(10px)', cursor:'pointer',
                border:`1px solid ${T.line2}`, display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name={ic} size={20} c="#fff" /></div>
            ))}
          </div>
          {/* poster + title overlap */}
          <div style={{ position:'absolute', left:20, right:20, bottom:0, display:'flex', gap:16, alignItems:'flex-end' }}>
            <Poster m={m} w={108} r={14} showTitle={false} />
            <div style={{ flex:1, paddingBottom:4 }}>
              <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:25, color:'#fff', letterSpacing:-0.5, lineHeight:1.04 }}>{m.t}</div>
              <div style={{ fontFamily:T.ui, fontSize:12.5, color:'rgba(255,255,255,0.82)', marginTop:6, fontWeight:600 }}>{m.y} · {runtime(m.m)}</div>
              <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:9 }}>
                <Stars r={m.r} size={14} /><span style={{ fontFamily:T.ui, fontSize:11.5, color:'rgba(255,255,255,0.6)' }}>· 128k ratings</span>
              </div>
            </div>
          </div>
        </div>
        {/* body */}
        <div style={{ flex:1, overflow:'hidden', padding:'18px 20px 30px' }}>
          {/* genres */}
          <div style={{ display:'flex', gap:8, marginBottom:18 }}>
            {m.g.map(g => <span key={g} style={{ padding:'7px 13px', borderRadius:999, background:T.surface, border:`1px solid ${T.line}`,
              fontFamily:T.ui, fontWeight:600, fontSize:12.5, color:T.sub }}>{g}</span>)}
          </div>
          {/* state buttons */}
          <div style={{ display:'flex', gap:10, marginBottom:20 }}>
            <StateBtn icon="heartF" label="Liked" c={T.green} k="liked" />
            <StateBtn icon="bookmark" label="Watchlist" c={T.purple} k="watchlist" />
            <StateBtn icon="eye" label="Watched" c={T.gold} k="watched" />
          </div>
          {/* synopsis */}
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:16, color:T.text, marginBottom:8 }}>Synopsis</div>
          <div style={{ fontFamily:T.ui, fontSize:14, color:T.sub, lineHeight:1.6, marginBottom:22 }}>{m.d} A visually staggering meditation on time, love and survival.</div>
          {/* your review */}
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:16, color:T.text, marginBottom:10 }}>Your review</div>
          <div style={{ borderRadius:16, background:T.surface, border:`1px solid ${T.line}`, padding:'14px 16px' }}>
            <div style={{ display:'flex', alignItems:'center', gap:10, marginBottom:9 }}>
              <Avatar person={ME} size={32} />
              <div style={{ flex:1 }}><div style={{ fontFamily:T.ui, fontWeight:700, fontSize:13.5, color:T.text }}>You</div></div>
              <div style={{ display:'flex', gap:2 }}>{[1,2,3,4,5].map(i => <Ic key={i} name="star" size={13} c={i<=5?T.gold:T.line2} />)}</div>
            </div>
            <div style={{ fontFamily:T.ui, fontSize:13.5, color:T.sub, lineHeight:1.55, fontStyle:'italic' }}>"Cried twice. The docking scene is unreal — a film that earns its three hours."</div>
            <div onClick={()=>go('review')} style={{ display:'inline-flex', alignItems:'center', gap:6, marginTop:11, fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:T.red, cursor:'pointer' }}>
              <Ic name="edit" size={15} c={T.red} />Edit review</div>
          </div>
        </div>
      </div>
    </Screen>
  );
}

// ── Profile ──
function ProfileScreen() {
  const stat = (n,l) => (
    <div style={{ flex:1, textAlign:'center' }}>
      <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:22, color:T.text }}>{n}</div>
      <div style={{ fontFamily:T.ui, fontSize:11.5, color:T.faint, marginTop:1, fontWeight:600 }}>{l}</div>
    </div>
  );
  const activity = [
    { ic:'heartF', c:T.green, txt:<>Liked <b>Parasite</b></>, t:'2h' },
    { ic:'eye',    c:T.gold,  txt:<>Watched <b>Whiplash</b></>, t:'Yesterday' },
    { ic:'bookmark',c:T.purple,txt:<>Saved <b>Dune: Part Two</b></>, t:'2d' },
    { ic:'edit',   c:T.red,   txt:<>Reviewed <b>Interstellar</b></>, t:'3d' },
  ];
  return (
    <Screen>
      <BottomNav active="profile" />
      <div style={{ flex:1, overflow:'hidden' }}>
        <TopSafe />
        <div style={{ padding:'2px 20px 8px', display:'flex', justifyContent:'flex-end' }}>
          <div onClick={()=>go('settings')} style={{ width:42, height:42, borderRadius:13, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
            display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="settings" size={21} c={T.text} /></div>
        </div>
        {/* identity */}
        <div style={{ display:'flex', flexDirection:'column', alignItems:'center', padding:'4px 20px 18px' }}>
          <div onClick={()=>go('editp')} style={{ cursor:'pointer' }}><Avatar person={ME} size={88} /></div>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:23, color:T.text, marginTop:13, letterSpacing:-0.4, whiteSpace:'nowrap' }}>{ME.name}</div>
          <div style={{ fontFamily:T.ui, fontSize:13, color:T.faint, marginTop:2 }}>{ME.handle}</div>
          <div style={{ fontFamily:T.ui, fontSize:13.5, color:T.sub, marginTop:10, textAlign:'center', lineHeight:1.5, maxWidth:280 }}>
            Sci-fi devotee & certified popcorn snob. Will absolutely make you watch the director's cut.</div>
        </div>
        {/* stats */}
        <div style={{ margin:'0 20px 20px', padding:'16px 12px', borderRadius:18, background:T.surface, border:`1px solid ${T.line}`,
          display:'flex' }}>
          {stat(ME.watched,'Watched')}
          <div style={{ width:1, background:T.line }} />
          {stat(58,'Liked')}
          <div style={{ width:1, background:T.line }} />
          {stat(14,'Saved')}
        </div>
        {/* favorite genres */}
        <div style={{ padding:'0 20px 18px' }}>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:15, color:T.text, marginBottom:11 }}>Favorite genres</div>
          <div style={{ display:'flex', flexWrap:'wrap', gap:8 }}>
            {['Sci-Fi','Drama','Thriller','Animation','Romance'].map((g,i) => (
              <span key={g} style={{ padding:'8px 14px', borderRadius:999, fontFamily:T.ui, fontWeight:700, fontSize:13,
                color: i===0?'#fff':T.sub, background: i===0?'transparent':T.surface, backgroundImage:i===0?T.grad:'none',
                border:`1px solid ${i===0?'transparent':T.line}` }}>{g}</span>
            ))}
          </div>
        </div>
        {/* activity */}
        <div style={{ flex:1, overflow:'hidden', padding:'0 20px 110px' }}>
          <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:15, color:T.text, marginBottom:12 }}>Recent activity</div>
          {activity.map((a,i) => (
            <div key={i} style={{ display:'flex', alignItems:'center', gap:13, padding:'11px 0', borderBottom:`1px solid ${T.line}` }}>
              <div style={{ width:40, height:40, borderRadius:12, background:hexA(a.c,0.14), display:'flex', alignItems:'center', justifyContent:'center' }}>
                <Ic name={a.ic} size={19} c={a.c} /></div>
              <div style={{ flex:1, fontFamily:T.ui, fontSize:14, color:T.sub }}>{a.txt}</div>
              <span style={{ fontFamily:T.ui, fontSize:11.5, color:T.faint }}>{a.t}</span>
            </div>
          ))}
        </div>
      </div>
    </Screen>
  );
}

// ── Notifications ──
function NotificationsScreen() {
  const [allRead, setAllRead] = React.useState(false);
  const items = [
    { kind:'req',   p:FRIENDS[4], txt:<><b>Kojo Mensah</b> sent you a friend request</>, t:'5m', unread:true, action:'req' },
    { kind:'invite',p:FRIENDS[1], txt:<><b>Sana Iyer</b> invited you to <b>Friday Sci-Fi Night</b></>, t:'12m', unread:true, action:'invite' },
    { kind:'start', p:FRIENDS[0], txt:<>Voting started in <b>Friday Sci-Fi Night</b> — jump in!</>, t:'18m', unread:true, ic:'film', c:T.purple },
    { kind:'result',p:FRIENDS[3], txt:<>Results are ready: tonight you're watching <b>Interstellar</b></>, t:'1h', ic:'sparkle', c:T.gold },
    { kind:'like',  p:FRIENDS[5], txt:<><b>Ivy Chen</b> liked your review of <b>Whiplash</b></>, t:'3h', ic:'heartF', c:T.green },
  ];
  return (
    <Screen>
      <div style={{ flex:1, overflow:'hidden' }}>
        <TopSafe />
        <div style={{ padding:'2px 20px 16px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
          <div style={{ display:'flex', alignItems:'center', gap:12 }}>
            <div onClick={()=>back()} style={{ width:40, height:40, borderRadius:12, background:T.surface, border:`1px solid ${T.line}`, cursor:'pointer',
              display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name="chevL" size={20} c={T.text} /></div>
            <div style={{ fontFamily:T.disp, fontWeight:800, fontSize:27, letterSpacing:-0.6, color:T.text }}>Activity</div>
          </div>
          <span onClick={()=>setAllRead(true)} style={{ fontFamily:T.ui, fontWeight:700, fontSize:13, color: allRead?T.faint:T.red, cursor:'pointer' }}>Mark all read</span>
        </div>
        <div style={{ flex:1, overflow:'hidden', padding:'0 14px' }}>
          {items.map((n,i) => { const unread = n.unread && !allRead; return (
            <div key={i} style={{ display:'flex', gap:13, padding:'13px 12px', borderRadius:16, marginBottom:4,
              background: unread ? T.surface : 'transparent', border:`1px solid ${unread?T.line:'transparent'}` }}>
              <div style={{ position:'relative', flexShrink:0 }}>
                <Avatar person={n.p} size={46} />
                {n.ic && <div style={{ position:'absolute', bottom:-3, right:-3, width:22, height:22, borderRadius:'50%', background:n.c,
                  border:`2.5px solid ${T.bg}`, display:'flex', alignItems:'center', justifyContent:'center' }}><Ic name={n.ic} size={12} c="#fff" /></div>}
              </div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ fontFamily:T.ui, fontSize:13.5, color:T.text, lineHeight:1.45 }}>{n.txt}</div>
                <div style={{ fontFamily:T.ui, fontSize:11.5, color:T.faint, marginTop:3 }}>{n.t} ago</div>
                {n.action==='req' && (
                  <div style={{ display:'flex', gap:8, marginTop:10 }}>
                    <div style={{ padding:'8px 18px', borderRadius:10, background:T.grad, fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:'#fff' }}>Accept</div>
                    <div style={{ padding:'8px 18px', borderRadius:10, background:T.surface2, border:`1px solid ${T.line2}`, fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:T.sub }}>Decline</div>
                  </div>
                )}
                {n.action==='invite' && (
                  <div style={{ display:'flex', gap:8, marginTop:10 }}>
                    <div style={{ padding:'8px 18px', borderRadius:10, background:T.grad, fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:'#fff' }}>Join</div>
                    <div style={{ padding:'8px 18px', borderRadius:10, background:T.surface2, border:`1px solid ${T.line2}`, fontFamily:T.ui, fontWeight:700, fontSize:12.5, color:T.sub }}>Later</div>
                  </div>
                )}
              </div>
              {unread && !n.ic && <div style={{ width:9, height:9, borderRadius:'50%', background:T.red, flexShrink:0, marginTop:5 }} />}
            </div>
          ); })}
        </div>
      </div>
    </Screen>
  );
}

Object.assign(window, { DetailScreen, ProfileScreen, NotificationsScreen });
