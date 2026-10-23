import { firebaseConfig, LIVE, fs, au, fn, functions, db, auth } from './firebase.js';

const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const toast = m => { const t=$('#toast'); if(!t) return; t.textContent=m; t.style.display='block'; setTimeout(()=>t.style.display='none',2600); };
const ICON = {'Blocked drain':'🏠','Bin full':'🗑️','Illegal dumping':'⚠️','Other':'⋯'};
const LABEL = {new:'New',in_progress:'In progress',resolved:'Resolved',rejected:'Rejected',pending:'Pending',pending_review:'Not approved yet',active:'Live',sold:'Sold',hidden:'Hidden',approved:'Approved',allowed:'AI: allowed',review:'AI: needs review'};
const S = Object.assign({model:'',thr:0.8,auto:true}, JSON.parse(localStorage.getItem('reloop') || '{}'));
const D = { reports:[], listings:[], bins:[] };
const BIN={domestic:{n:'Domestic bin',c:'#6b7a72',icon:'delete'},general:{n:'Domestic bin',c:'#6b7a72',icon:'delete'},recycle:{n:'Recycle bin',c:'#2f9e63',icon:'recycling'},organic:{n:'Organic',c:'#8a5a2b',icon:'delete'},ewaste:{n:'E-waste',c:'#3a7bd5',icon:'delete'},hazardous:{n:'Hazardous',c:'#c0392b',icon:'delete'}};
let page='home', map, markers={}, onChange=()=>{}, fb={fs,au,fn,functions,db,auth};

/* ---------- data layer: Firestore when configured, sample data otherwise ---------- */
const now = Date.now();
const DEMO = {
 reports:[
  {id:'r1',type:'Blocked drain',title:'Blocked drain',address:'Jalan Cheras Perdana',lat:3.0743,lng:101.7690,status:'in_progress',createdAt:now-3*864e5},
  {id:'r2',type:'Illegal dumping',title:'Illegal dumping',address:'Behind Block C, Taman Sri',lat:3.1078,lng:101.7420,status:'resolved',createdAt:now-9*864e5},
  {id:'r3',type:'Bin full',title:'Bin full',address:'Seksyen 7, Shah Alam',lat:3.0733,lng:101.5185,status:'new',createdAt:now-864e5},
  {id:'r4',type:'Other',title:'Broken recycling bin',address:'Taman Tun Dr Ismail',lat:3.1500,lng:101.6300,status:'new',createdAt:now-36e5}],
 listings:[
  {id:'l1',title:'Wooden chair (restored)',price:25,emoji:'🪑',seller:'Aina',status:'pending',createdAt:now-2*36e5},
  {id:'l2',title:'Glass jars, set of 12',price:10,emoji:'🫙',seller:'Raj',status:'approved',aiScore:.94,aiLabel:'allowed',createdAt:now-864e5},
  {id:'l3',title:'Used spray can (aerosol)',price:3,emoji:'🧴',seller:'Wei',status:'pending',aiScore:.31,aiLabel:'review',createdAt:now-5*36e5}],
 bins:[{id:'b1',name:'Taman Sri playground',type:'general',lat:3.1065,lng:101.7430},{id:'b2',name:'Cheras Perdana recycling point',type:'recycle',lat:3.0750,lng:101.7680}]
};

async function initData(){
  if(!LIVE){ D.reports=DEMO.reports; D.listings=DEMO.listings; D.bins=DEMO.bins; return; }
  await new Promise(resolve=>{
    let initialized=false;
    au.onAuthStateChanged(auth, async user=>{
      if(!user){ location.replace('signin.html'); return; }
      if(initialized) return;
      initialized=true;
      try{
        const [adminSnap,token]=await Promise.all([
          fs.getDoc(fs.doc(db,'admins',user.uid)),
          au.getIdTokenResult(user)
        ]);
        const enabled = user.email === 'test@gmail.com'
          || token.claims?.email === 'test@gmail.com'
          || (adminSnap.exists() && adminSnap.data()?.enabled === true)
          || token.claims?.admin === true;

        if(!enabled){
          toast('This account does not have admin access. Register with the admin key or contact an administrator.');
          await au.signOut(auth);
          location.replace('signin.html');
          return;
        }

        const who = $('#who');
        if (who) {
          who.innerHTML='Signed in as<br><b>'+esc(user.email||user.uid)+'</b><br><small>UID: '+esc(user.uid)+'</small><br><span>Admin access enabled</span><br><button class="btn ghost" id="wo">Sign out</button>';
          const wo = $('#wo');
          if (wo) wo.onclick=()=>au.signOut(auth).then(()=>location.replace('signin.html'));
        }

        ['reports','listings','bins'].forEach(c=>{
          const q = fs.collection(db, c);
          fs.onSnapshot(q, snap=>{
            D[c] = snap.docs.map(d=>{
              const x = d.data();
              const createdAt = x.createdAt?.toMillis
                ? x.createdAt.toMillis()
                : (x.createdAt || x.timestamp?.toMillis?.() || x.timestamp || (x.date ? new Date(x.date).getTime() : Date.now()));
              return {id:d.id, ...x, createdAt};
            });
            if (c !== 'bins') {
              D[c].sort((a,b) => (b.createdAt || 0) - (a.createdAt || 0));
            }
            onChange();
          }, e => console.warn('Firestore subscription (' + c + '):', e.code || e.message));
        });
        resolve();
      }catch(e){
        toast('Could not verify admin access: '+(e.code||e.message));
        await au.signOut(auth);
        location.replace('signin.html');
      }
    });
  });
}

async function patch(col,id,data){
  if(!LIVE){ Object.assign(D[col].find(x=>x.id===id)||{}, data); onChange(); return; }
  await fb.fs.updateDoc(fb.fs.doc(fb.db,col,id),data);
}

async function add(col,data){
  if(!LIVE){ D[col].unshift({id:'d'+Date.now(),createdAt:Date.now(),...data}); onChange(); return; }
  await fb.fs.addDoc(fb.fs.collection(fb.db,col),{...data,createdAt:fb.fs.serverTimestamp()});
}

async function removeDoc(col,id){
  if(!LIVE){ D[col]=D[col].filter(x=>x.id!==id); onChange(); return; }
  await fb.fs.deleteDoc(fb.fs.doc(fb.db,col,id));
}

/* ---------- AI check (Teachable Machine image model) ---------- */
let model;
const loadJs = u => new Promise((ok,no)=>{const s=document.createElement('script');s.src=u;s.onload=ok;s.onerror=no;document.head.append(s)});
const checking=new Set();

function autoCheck(){
  if(!S.model) return;
  D.listings.forEach(l=>{ if(['pending','pending_review'].includes(l.status)&&l.aiScore==null&&(l.imageUrl||l.imageUrls?.length)&&!checking.has(l.id)){ checking.add(l.id); aiCheck(l.id,true); } });
}

async function aiCheck(id,quiet){
  const say=m=>{ if(!quiet) toast(m); };
  const l=D.listings.find(x=>x.id===id);
  if(!S.model) return say('Add your model URL in Settings first');
  const imageUrl=l?.imageUrl||l?.imageUrls?.[0];
  if(!l||!imageUrl) return say('This listing has no photo to check');
  try{
    say('Checking…');
    if(!model){
      await loadJs('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@1.3.1/dist/tf.min.js');
      await loadJs('https://cdn.jsdelivr.net/npm/@teachablemachine/image@0.8/dist/teachablemachine-image.min.js');
      const u=S.model.replace(/\/?$/,'/');
      model=await tmImage.load(u+'model.json',u+'metadata.json');
    }
    const img=new Image(); img.crossOrigin='anonymous'; img.src=imageUrl; await img.decode();
    const p=await model.predict(img); const ok=p.find(x=>x.className.toLowerCase()==='allowed');
    const score=ok?ok.probability:0, pass=score>=S.thr;
    const up={aiScore:score,aiLabel:pass?'allowed':'review'}; if(pass&&S.auto) up.status='active';
    await patch('listings',id,up); toast(pass?(S.auto?'AI approved: '+l.title:'AI: '+l.title+' looks OK'):'AI flagged for review: '+l.title);
  }catch(e){ say('AI check failed: '+e.message); }
}

/* ---------- views ---------- */
const ago = t => {
  if (!t) return '';
  const m=Math.round((Date.now()-t)/6e4);
  return m<1?'just now':m<60?m+' min ago':m<1440?Math.round(m/60)+' h ago':Math.round(m/1440)+' d ago';
};
const count = (a,k,v) => a.filter(x=>x[k]===v).length;

function repRow(r){
  const address = r.address || r.locationName || r.location || 'Location provided';
  return `<div class="row ${r.status==='resolved'?'res':''}" data-rid="${esc(r.id)}"><div class="ic">${ICON[r.type]||'⋯'}</div>
 <div class="m"><b>${esc(r.title||r.type||'Report')}</b><span>${esc(address)} · ${r.createdAt?ago(r.createdAt):''}</span>
 ${page==='reports'?`<div class="acts">${r.status==='new'?`<button class="btn" data-a="in_progress" data-id="${esc(r.id)}">Accept</button><button class="btn red" data-a="rejected" data-id="${esc(r.id)}">Reject</button>`:''}${r.status==='in_progress'?`<button class="btn" data-a="resolved" data-id="${esc(r.id)}">Mark resolved</button>`:''}</div>`:''}</div>
 <span class="chip s-${esc(r.status)}">${LABEL[r.status]||esc(r.status)}</span></div>`;
}

function home(){
  const R=D.reports,L=D.listings;
  return `<h2>Overview</h2><p class="sub">Keep your neighbourhood clean</p>
 <div class="tiles"><div class="tile t2"><b>${count(R,'status','new')}</b><span>New reports to review</span></div>
 <div class="tile t1"><b>${count(R,'status','in_progress')}</b><span>Reports in progress</span></div>
 <div class="tile t3"><b>${L.filter(x=>['pending','pending_review'].includes(x.status)).length}</b><span>Listings waiting for approval</span></div>
 <div class="tile t4"><b>${count(L,'status','active')}</b><span>Items live on ReMarket</span></div></div>
 <h3>Reports by type</h3><div class="quick">${Object.keys(ICON).map(t=>`<div class="q"><i>${ICON[t]}</i><b>${count(R,'type',t)}</b>${t}</div>`).join('')}</div>
 <h3>Latest reports</h3><div class="card">${R.slice(0,4).map(repRow).join('')||'<p class="empty">No reports yet.</p>'}</div>`;
}

function reports(){
  return `<h2>Reports</h2><p class="sub">Every report lodged in the app appears here with its location.</p>
 <div class="split"><div id="map"></div><div class="card list">${D.reports.map(repRow).join('')||'<p class="empty">No reports yet. New ones from the app show up here live.</p>'}</div></div>`;
}

function listingCard(l){
  const imageUrl=l.imageUrl||(Array.isArray(l.imageUrls)?l.imageUrls.find(u=>typeof u==='string'&&u.trim()):'');
  return `<div class="card item"><div class="img">${imageUrl?`<img src="${esc(imageUrl)}" alt="${esc(l.title||'Listing photo')}">`:esc(l.emoji||'📦')}</div>
 <b>${esc(l.title)}</b><div class="note">RM ${esc(l.price)} · ${esc(l.seller||'user')}</div>
 ${l.aiScore!=null?`<div class="bar"><i style="width:${Math.round(l.aiScore*100)}%"></i></div><span class="chip s-${esc(l.aiLabel)}">${LABEL[l.aiLabel]} · ${Math.round(l.aiScore*100)}%</span>`:`<div class="note">${S.model?'AI check runs automatically…':'AI auto-check is off: add your model URL in Settings'}</div>`}
 <div style="margin-top:8px"><span class="chip s-${esc(l.status)}">${LABEL[l.status]||esc(l.status)}</span></div>
 <div class="acts">${l.aiScore!=null?`<button class="btn ghost" data-ai="${esc(l.id)}">Re-check</button>`:''}
 ${['pending','pending_review'].includes(l.status)?`<button class="btn" data-l="active" data-id="${esc(l.id)}">Approve</button><button class="btn red" data-l="rejected" data-id="${esc(l.id)}">Deny</button>`:''}
 ${l.status==='active'?`<button class="btn red" data-l="hidden" data-id="${esc(l.id)}">Hide</button>`:''}
 ${['sold','hidden','rejected'].includes(l.status)?`<button class="btn" data-l="active" data-id="${esc(l.id)}">Restore live</button><button class="btn red" data-delete-listing="${esc(l.id)}">Delete item</button>`:''}</div></div>`;
}

function market(){
  const groups=[
    {title:'Not approved yet',items:D.listings.filter(l=>['pending','pending_review'].includes(l.status)),empty:'No items are waiting for approval.'},
    {title:'Approved items (live)',items:D.listings.filter(l=>l.status==='active'),empty:'No live items.'},
    {title:'Hidden (sold)',items:D.listings.filter(l=>['sold','hidden','rejected'].includes(l.status)),empty:'No hidden or sold items.'}
  ];
  return `<h2>ReMarket</h2><p class="sub">Review listings, manage live items, and find sold or hidden items.</p>${groups.map(g=>`<section class="market-group"><h3>${g.title} <span class="note">(${g.items.length})</span></h3><div class="grid">${g.items.map(listingCard).join('')||`<p class="empty">${g.empty}</p>`}</div></section>`).join('')}`;
}

function bins(){
  return `<h2>Bin Map</h2><p class="sub">Search for a place or click the map, drag the pin to fine-tune, then save. It appears in the user app.</p>
 <div class="split"><div id="map"></div><div>
 <div class="card"><b>Add a bin</b>
 <label for="bq">Search a place</label>
 <div style="display:flex;gap:6px"><input id="bq" placeholder="e.g. Taman Sri Muda, Shah Alam"><button class="btn" id="bg">Search</button></div>
 <div id="br"></div>
 <div class="acts"><button class="btn ghost" id="bm">📍 Use my current location</button></div>
 <label for="bn">Name / landmark</label><input id="bn" placeholder="e.g. Taman Sri playground">
 <label for="bt">Bin type</label><select id="bt"><option value="Domestic">Domestic bin</option><option value="Recycle">Recycle bin</option></select>
 <p class="note" id="bc">No location chosen yet. Click the map.</p>
 <div class="acts"><button class="btn" id="bs">Save bin</button></div></div>
 <div class="card list" id="bl" style="margin-top:14px"></div></div></div>`;
}

let pick=null, binMarks=[], sres=[];

function showPick(){
  if(!pick) return;
  const p=pick.getLatLng();
  $('#bc').textContent='Location: '+p.lat.toFixed(5)+', '+p.lng.toFixed(5);
}

function setPick(ll,label){
  if(pick) {
    pick.setLatLng(ll);
  } else {
    pick=L.marker(ll,{draggable:true}).addTo(map);
    pick.on('dragend',showPick);
  }
  showPick();
  if(label&&!$('#bn').value) $('#bn').value=label;
}

async function searchPlace(){
  const q=$('#bq').value.trim(); if(!q) return;
  $('#br').innerHTML='<p class="note">Searching…</p>';
  try{
    const j=await (await fetch('https://photon.komoot.io/api/?limit=5&q='+encodeURIComponent(q))).json();
    sres=j.features||[];
    $('#br').innerHTML=sres.length?sres.map((x,i)=>{const p=x.properties;const t=[p.name,p.street,p.district||p.city,p.state].filter(Boolean).join(', ');
      return `<div class="row" data-sr="${i}"><div class="m"><b>${esc(p.name||t)}</b><span>${esc(t)}</span></div></div>`;}).join(''):'<p class="note">No results. Try a nearby landmark, or click the map.</p>';
  }catch(e){ $('#br').innerHTML='<p class="note">Search failed. You can still click the map.</p>'; }
}

function drawBinMap(){
  if(map) map.remove(); map=L.map('map').setView([3.1,101.65],10); pick=null; binMarks=[];
  addBase(map);
  map.on('click',e=>setPick(e.latlng));
  $('#bm').onclick=()=>{
    if(!navigator.geolocation) return toast('Location is not supported here');
    navigator.geolocation.getCurrentPosition(p=>{
      const ll=[p.coords.latitude,p.coords.longitude];
      map.flyTo(ll,18);
      setPick(ll);
    },()=>toast('Could not get your location. Allow location access in the browser.'));
  };
  $('#bg').onclick=searchPlace;
  $('#bq').onkeydown=e=>{ if(e.key==='Enter') searchPlace(); };
  $('#bs').onclick=async()=>{
    if(!pick) return toast('Click the map to choose a location');
    const name=$('#bn').value.trim(); if(!name) return toast('Give the bin a name');
    const ll=pick.getLatLng();
    try{
      await add('bins',{
        name,
        type: $('#bt').value, // 'Domestic' or 'Recycle'
        status: 'empty',
        fill: 0,
        location: new fb.fs.GeoPoint(ll.lat, ll.lng),
        lat: ll.lat,
        lng: ll.lng
      });
    }catch(e){ return toast('Could not save: '+e.message); }
    $('#bn').value=''; map.removeLayer(pick); pick=null; $('#bc').textContent='Saved. Click the map to add another.'; toast('Bin added');
  };
  refreshBins(true);
}

function binType(b){
  const raw=String(b.type||b.binType||b.category||b.wasteType||'domestic').toLowerCase().replace(/[ _-]/g,'');
  if(raw.includes('recycl')) return 'recycle';
  if(['domestic','general','generalwaste','household','domesticwaste'].includes(raw)) return 'domestic';
  return BIN[raw]?raw:'domestic';
}

function binDetails(b){
  const emptied=b.emptied?.toDate?b.emptied.toDate().toLocaleString():b.emptied;
  const fields=[['Status',b.status],['Fill level',typeof b.fill==='number'?`${b.fill}%`:null],['Last emptied',emptied],['Maintenance note',b.maintenanceNote],['Address',b.address||b.locationName],['Details',b.description||b.details],['Accepted items',b.acceptedItems||b.materials],['Hours',b.openingHours||b.hours],['Contact',b.contact||b.phone]];
  return fields.filter(([,v])=>v!=null&&v!=='' ).map(([label,value])=>`<div><b>${label}:</b> ${esc(Array.isArray(value)?value.join(', '):value)}</div>`).join('');
}

function binCoords(b){
  const location=b.location;
  const lat=b.lat??b.latitude??location?.latitude??location?.lat;
  const lng=b.lng??b.longitude??location?.longitude??location?.lng;
  return [Number(lat),Number(lng)];
}

function binStatusColor(status){
  return ({full:'#e53935',empty:'#2e9e5b',half:'#f2a900',maintenance:'#808080',maintainence:'#808080'})[String(status||'').toLowerCase()]||'#808080';
}

function refreshBins(fit){
  binMarks.forEach(m=>m.remove()); binMarks=[]; const pts=[];
  D.bins.filter(b=>['domestic','recycle'].includes(binType(b))).forEach(b=>{
    const [lat,lng]=binCoords(b); if(!Number.isFinite(lat)||!Number.isFinite(lng)) return;
    const type=binType(b),cfg=BIN[type],info=binDetails(b),pinColor=binStatusColor(b.status);
    const icon=L.divIcon({className:'bin-pin',html:`<span style="background:${pinColor}"><i class="material-icons">${cfg.icon}</i></span>`,iconSize:[48,48],iconAnchor:[24,24],popupAnchor:[0,-24]});
    binMarks.push(L.marker([lat,lng],{icon}).addTo(map).bindPopup(`<b>${esc(b.name||cfg.n)}</b><div>${esc(cfg.n)}</div>${info?`<hr>${info}`:''}`)); pts.push([lat,lng]); });
  if(fit&&pts.length) map.fitBounds(pts,{padding:[40,40],maxZoom:14});
  $('#bl').innerHTML=D.bins.filter(b=>['domestic','recycle'].includes(binType(b))).map(b=>{const cfg=BIN[binType(b)],info=binDetails(b); return `<div class="row" data-bin="${esc(b.id)}"><div class="ic" style="background:${binStatusColor(b.status)};color:#fff"><i class="material-icons">${cfg.icon}</i></div><div class="m"><b>${esc(b.name||cfg.n)}</b><span>${esc(cfg.n)}${b.address?` · ${esc(b.address)}`:''}${b.description?` · ${esc(b.description)}`:''}</span>${info?`<div class="note">${info}</div>`:''}</div><button class="btn red" data-del="${esc(b.id)}">Delete</button></div>`;}).join('')||'<p class="empty">No domestic or recycling bins found in the database.</p>';
}

function settings(){
  return `<h2>Settings</h2><p class="sub">Connection and AI moderation.</p>
 <div class="card"><b>Connection</b><p class="note">${LIVE?'Connected to Firebase project <b>'+esc(firebaseConfig.projectId)+'</b>':'Demo mode: sample data only. Add your Firebase config at the top of the script to go live.'}</p>
 <label for="mu">AI model URL (Teachable Machine)</label><input id="mu" value="${esc(S.model)}" placeholder="https://teachablemachine.withgoogle.com/models/XXXX/">
 <p class="note">Train a model with two classes named “allowed” and “not allowed”, then paste its shared link.</p>
 <label for="th">Minimum confidence to pass (0 to 1)</label><input id="th" type="number" min="0" max="1" step="0.05" value="${S.thr}">
 <label style="display:flex;gap:8px;align-items:center"><input id="au" type="checkbox" style="width:auto" ${S.auto?'checked':''}> Auto-approve items that pass (others wait for your review)</label>
 <div class="acts"><button class="btn" id="sv">Save settings</button>${LIVE?'<button class="btn ghost" id="so">Sign out</button>':''}</div></div>`;
}

function addBase(m){
  const t=(u,a)=>L.tileLayer(u,{maxZoom:19,attribution:a});
  const street=t('https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}','Tiles © Esri');
  const sat=t('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}','Tiles © Esri');
  const osm=t('https://tile.openstreetmap.org/{z}/{x}/{y}.png','© OpenStreetMap');
  street.addTo(m); L.control.layers({'Street':street,'Satellite':sat,'OpenStreetMap':osm}).addTo(m);
}

function drawMap(){
  if(map){map.remove();} map=L.map('map').setView([3.1,101.65],10); markers={};
  addBase(map);
  const col={new:'#f08a3c',in_progress:'#e0a31a',resolved:'#2f9e63',rejected:'#999'}; const pts=[];
  D.reports.filter(r=>typeof r.lat==='number'&&typeof r.lng==='number').forEach(r=>{
    const m=L.circleMarker([r.lat,r.lng],{radius:10,color:'#fff',weight:2,fillColor:col[r.status]||'#888',fillOpacity:1}).addTo(map)
      .bindPopup(`<b>${esc(r.title||r.type)}</b><br>${esc(r.address||r.location||'')} <br>${LABEL[r.status]||esc(r.status)}`);
    markers[r.id]=m; pts.push([r.lat,r.lng]); });
  if(pts.length) map.fitBounds(pts,{padding:[40,40],maxZoom:14});
}

function render(){
  $('#main').innerHTML = {home,reports,bins,market,settings}[page]();
  if(page==='market') document.querySelectorAll('#main .item .img img').forEach(img=>img.addEventListener('error',()=>{
    const box=img.parentElement;
    if(box){ box.textContent='Image unavailable'; box.classList.add('image-unavailable'); }
  },{once:true}));
  document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('on',b.dataset.p===page));
  if(page==='reports') drawMap();
  if(page==='bins') drawBinMap();
  if(page==='settings'){
    $('#sv').onclick=()=>{S.model=$('#mu').value.trim();S.thr=+$('#th').value||0.8;S.auto=$('#au').checked;model=null;localStorage.setItem('reloop',JSON.stringify(S));toast('Settings saved');};
    if($('#so')) $('#so').onclick=()=>fb.au.signOut(fb.auth).then(()=>location.reload());
  }
}

onChange=()=>{ autoCheck(); if(page==='bins') refreshBins(); else if(page!=='settings') render(); };

document.addEventListener('click',e=>{
  const n=e.target.closest('nav button'); if(n){page=n.dataset.p;render();return;}
  const a=e.target.closest('[data-a]'); if(a){patch('reports',a.dataset.id,{status:a.dataset.a});toast('Report updated');return;}
  const l=e.target.closest('[data-l]'); if(l){patch('listings',l.dataset.id,{status:l.dataset.l}).then(()=>toast(({active:'Listing is live',rejected:'Listing denied',sold:'Listing marked sold'})[l.dataset.l]||'Listing updated')).catch(e=>toast('Could not update listing: '+(e.code||e.message)));return;}
  const dl=e.target.closest('[data-delete-listing]'); if(dl){if(!confirm('Permanently delete this listing? This cannot be undone.')) return; removeDoc('listings',dl.dataset.deleteListing).then(()=>toast('Listing deleted')).catch(e=>toast('Could not delete listing: '+(e.code||e.message)));return;}
  const sr=e.target.closest('[data-sr]'); if(sr&&map){ const x=sres[sr.dataset.sr]; const [lng,lat]=x.geometry.coordinates; map.flyTo([lat,lng],17); setPick([lat,lng],x.properties.name); $('#br').innerHTML=''; return; }
  const d=e.target.closest('[data-del]'); if(d){ if(confirm('Delete this bin?')) removeDoc('bins',d.dataset.del).then(()=>toast('Bin deleted')); return; }
  const bin=e.target.closest('[data-bin]'); if(bin&&map){ const b=D.bins.find(x=>x.id===bin.dataset.bin); if(b){const [lat,lng]=binCoords(b);const marker=binMarks.find(m=>{const ll=m.getLatLng();return ll.lat===lat&&ll.lng===lng;}); if(marker){map.flyTo(marker.getLatLng(),16);marker.openPopup();}} return; }
  const i=e.target.closest('[data-ai]'); if(i){aiCheck(i.dataset.ai);return;}
  const r=e.target.closest('[data-rid]'); if(r&&map&&markers[r.dataset.rid]){const m=markers[r.dataset.rid];map.flyTo(m.getLatLng(),15);m.openPopup();}
});

render();
if (LIVE) {
  const notice = document.createElement('p');
  notice.id = 'startupNotice';
  notice.className = 'note';
  notice.textContent = 'Checking your admin access...';
  $('#main').prepend(notice);
}

try {
  await initData();
  const notice = $('#startupNotice');
  if (notice) notice.remove();
  render();
  autoCheck();
} catch (error) {
  console.error('Dashboard startup failed:', error);
  $('#main').innerHTML = `<h2>Could not load the admin console</h2><p class="sub">${esc(error.code || error.message || 'Unknown startup error')}</p><p class="note">Refresh the page. If this keeps happening, check the browser console for details.</p>`;
}
