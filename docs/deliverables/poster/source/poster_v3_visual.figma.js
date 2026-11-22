// QORA A1 poster — visual, low-text layout, run with use_figma.
// v5: real numbers only (project records + pq-core measurements of 16 Nov 2026), no modelled chart,
// one shared grid: 2 columns of 830 px (Problem, Solution) and 3 columns of 546.7 px (Core, Results), 20 px gutters.
// Clones the team's green poster (SOURCE_ID), keeps its header (logos, names, supervisors) and technology
// logo chips, rebuilds everything below, and places the result to the right of the rightmost frame.
// Frame is 1800 x 2548 (A1 ratio). Returns {fits}: false means the bottom overflows.

// Node id of the green poster in the file you run this in (21:2 in yKBtUtSe6RKDZYokBKwC9Y).
const SOURCE_ID='21:2';

const hex=h=>({r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255});
const S=h=>[{type:'SOLID',color:hex(h)}];
const G='2E6B4E',G2='1F4A36',LG='E2EEE5',LGB='B9D3C1',MG='8FB59B',BG='F4F2EC',CHIP='F0EEE7',BD='DAD6CB',GRID='E6E2D8',DK='262D2E',INK='1E2324',SUB='4F5653',MUT='5C625F',ARW='6B716E',W='FFFFFF';
const PF='Playfair Display';
await Promise.all([['DM Sans','Regular'],['DM Sans','Medium'],['DM Sans','Bold'],[PF,'Bold'],[PF,'Medium Italic']].map(([family,style])=>figma.loadFontAsync({family,style})));

function T(parent,str,size,o={}){const t=figma.createText();t.fontName={family:o.f||'DM Sans',style:o.s||'Regular'};t.characters=str;t.fontSize=size;t.fills=S(o.c||INK);if(o.lh)t.lineHeight={unit:'PIXELS',value:o.lh};if(o.al)t.textAlignHorizontal=o.al;if(o.ls)t.letterSpacing={unit:'PIXELS',value:o.ls};parent.appendChild(t);
 if(o.w){t.resize(o.w,t.height);t.textAutoResize='HEIGHT';}else if(o.fill){t.textAutoResize='HEIGHT';t.layoutSizingHorizontal='FILL';}if(o.x!=null){t.x=o.right?o.x-t.width:(o.center?o.x-t.width/2:o.x);t.y=o.y;}return t;}
function B(parent,dir,o={}){const f=figma.createAutoLayout(dir);f.name=o.n||'Box';f.itemSpacing=o.gap??0;const p=o.p??0;f.paddingLeft=f.paddingRight=o.px??p;f.paddingTop=f.paddingBottom=o.py??p;f.fills=o.bg?S(o.bg):[];if(o.r)f.cornerRadius=o.r;if(o.stroke){f.strokes=S(o.stroke);f.strokeWeight=o.sw||1;if(o.dash)f.dashPattern=o.dash;}if(o.ai)f.counterAxisAlignItems=o.ai;if(o.jc)f.primaryAxisAlignItems=o.jc;if(parent)parent.appendChild(f);
 if(o.w){f.resize(o.w,Math.max(f.height,1));f.layoutSizingHorizontal='FIXED';}if(o.h){f.resize(f.width,o.h);f.layoutSizingVertical='FIXED';}if(o.fill)f.layoutSizingHorizontal='FILL';if(o.fillV)f.layoutSizingVertical='FILL';return f;}
function F(parent,w,h,name){const f=figma.createFrame();f.name=name||'Canvas';f.resize(w,h);f.fills=[];f.clipsContent=false;parent.appendChild(f);return f;}
function R(parent,x,y,w,h,col,o={}){const r=figma.createRectangle();parent.appendChild(r);r.resize(Math.max(w,0.5),h);r.x=x;r.y=y;r.fills=S(col);if(o.r!=null)r.cornerRadius=o.r;if(o.tl!=null){r.topLeftRadius=o.tl;r.bottomLeftRadius=o.tl;r.topRightRadius=o.tr||0;r.bottomRightRadius=o.tr||0;}if(o.stroke){r.strokes=S(o.stroke);r.strokeWeight=o.sw||1.5;}return r;}
function path(parent,d,o={}){const v=figma.createVector();parent.appendChild(v);v.vectorPaths=[{windingRule:o.fill?'NONZERO':'NONE',data:d}];v.strokes=o.fill?[]:S(o.c||ARW);v.strokeWeight=o.w||2;v.fills=o.fill?S(o.c):[];if(o.dash)v.dashPattern=o.dash;return v;}
function arrow(parent,x1,y1,x2,y2,col){const L=Math.hypot(x2-x1,y2-y1),ux=(x2-x1)/L,uy=(y2-y1)/L,nx=-uy,ny=ux,f=n=>n.toFixed(1);
 path(parent,`M ${f(x1)} ${f(y1)} L ${f(x2-ux*8)} ${f(y2-uy*8)}`,{c:col||ARW,w:2.5});
 path(parent,`M ${f(x2)} ${f(y2)} L ${f(x2-ux*11+nx*6)} ${f(y2-uy*11+ny*6)} L ${f(x2-ux*11-nx*6)} ${f(y2-uy*11-ny*6)} Z`,{fill:1,c:col||ARW});}
function card(parent,o={}){return B(parent,'VERTICAL',{n:o.n||'Card',bg:o.bg||W,stroke:o.stroke||BD,r:o.r||14,p:o.p??22,gap:o.gap??14,fill:o.fill!==false,w:o.w,fillV:o.fillV});}
function chip(parent,str,o={}){const b=B(parent,'HORIZONTAL',{n:str,bg:o.bg||CHIP,r:o.r||6,px:10,py:5,stroke:o.stroke});T(b,str,o.size||15,{s:o.s||'Regular',c:o.c||INK});return b;}
function wrapRow(parent,gap,name){const r=B(parent,'HORIZONTAL',{n:name||'Chips',gap,fill:true});r.layoutWrap='WRAP';r.counterAxisSpacing=gap;return r;}
function stat(parent,num,label){const t=B(parent,'VERTICAL',{n:num,bg:BG,r:10,px:14,py:12,gap:2,fill:true,fillV:true});T(t,num,40,{f:PF,s:'Bold',c:G,lh:46});T(t,label,15,{lh:20,fill:true});return t;}
// every heading: number + title, optional italic tagline inline after it (same treatment in all sections)
function heading(parent,num,title,tag){const h=B(parent,'HORIZONTAL',{n:'Heading',gap:20,ai:'BASELINE',fill:true,h:40});
 const t=T(h,`${num}  ${title}`,32,{f:PF,s:'Bold',lh:38});t.setRangeFills(0,num.length,S(G));if(tag)T(h,tag,21,{f:PF,s:'Medium Italic',c:G,lh:28});return h;}

// ---------- grid ----------
const CW=1680, GUT=20, HALF=(CW-GUT)/2, THIRD=(CW-2*GUT)/3;

// ---------- clone, keep header and tech chips ----------
const src=await figma.getNodeByIdAsync(SOURCE_ID);
const C=src.clone();C.name='A1 Poster - Visual (v5)';C.x=Math.max(...figma.currentPage.children.map(n=>n.x+n.width))+300;C.y=src.y;
const header=C.children.find(n=>n.name==='Header');
let techChips=[];const techFrame=C.findOne(n=>n.name==='Technology')||C.findOne(n=>n.name==='Stack groups');
if(techFrame)techChips=techFrame.findAll(n=>n.type==='FRAME'&&n.parent&&(n.parent===techFrame||n.parent.name==='logos')&&n.findAll(x=>x.type==='TEXT').length>0);
const holder=figma.createFrame();holder.name='tmp';holder.visible=false;figma.currentPage.appendChild(holder);for(const c of techChips)holder.appendChild(c);
for(const k of [...C.children])if(!header||k.id!==header.id)k.remove();
C.fills=S(BG);C.paddingLeft=C.paddingRight=C.paddingTop=C.paddingBottom=0;C.itemSpacing=0;C.primaryAxisAlignItems='MIN';
if(header){header.layoutSizingHorizontal='FILL';header.fills=S(DK);header.topLeftRadius=header.topRightRadius=0;
 const tb=header.findOne(n=>n.name==='Title block');if(tb){const title=tb.findAllWithCriteria({types:['TEXT']}).sort((a,b)=>b.fontSize-a.fontSize)[0];title.fontName={family:PF,style:'Bold'};title.characters='Post-Quantum Secured Programmable Wealth Platform\nfor Tokenized Real-World Assets';title.fontSize=44;title.lineHeight={unit:'PIXELS',value:52};}}
const M=B(C,'VERTICAL',{n:'Main',px:60,py:28,fill:true});M.primaryAxisAlignItems='SPACE_BETWEEN';

// ---------- 1. PROBLEM (2 columns) ----------
const s1=B(M,'VERTICAL',{n:'1 Problem',gap:12,fill:true});
heading(s1,'1.','Problem Statement','Security makes inclusion unaffordable. Inclusion without security is not ownership.');
const p=B(s1,'HORIZONTAL',{n:'Problem cards',gap:GUT,fill:true});
const inner=HALF-48, VIS=112, STH=108;
function pcard(name,title,lead){const c=card(p,{n:name,w:HALF});const h=B(c,'VERTICAL',{n:'Head',gap:6,fill:true,h:58});T(h,title,22,{s:'Bold',lh:28,fill:true});T(h,lead,17,{c:SUB,lh:24,fill:true});return c;}
// 1.1
const c1=pcard('1.1 Financial','1.1  Financial exclusion & unsafe micro-lending','Tokenised real-world assets are built for institutions, not small savers.');
const v1=F(c1,inner,VIS,'Minimum investment bars');
const a1=T(v1,'Existing tokenised-asset funds · minimum $5 M',15,{c:SUB,x:0,y:0});a1.setRangeFontName(a1.characters.indexOf('$5 M'),a1.characters.length,{family:'DM Sans',style:'Bold'});a1.setRangeFills(a1.characters.indexOf('$5 M'),a1.characters.length,S(INK));
R(v1,0,24,inner,26,MUT,{r:4});
const a2=T(v1,'This platform · minimum PKR 1,000',15,{c:SUB,x:0,y:58});a2.setRangeFontName(a2.characters.indexOf('PKR'),a2.characters.length,{family:'DM Sans',style:'Bold'});a2.setRangeFills(a2.characters.indexOf('PKR'),a2.characters.length,S(G));
R(v1,0,82,4,26,G,{r:2});T(v1,'(enlarged — at true scale it would be thinner than a hair)',14,{c:SUB,x:14,y:86});
const st1=B(c1,'HORIZONTAL',{n:'Stats',gap:12,fill:true,h:STH});
stat(st1,'1 : 1','vault inflation attack: ~PKR 1,000 steals a PKR 1,000 deposit');stat(st1,'3 %','price move that makes $10 M+ of loans liquidatable');stat(st1,'$114 M','lost by one protocol to a single manipulated price feed');
// 1.2
const c2=pcard('1.2 Security','1.2  Quantum vulnerability of ownership records','Every record is signed with ECDSA, which Shor’s algorithm breaks.');
const tl=F(c2,inner,VIS,'ECDSA timeline');const x35=Math.round(inner*9/30);
T(tl,'2026',15,{s:'Bold',x:0,y:0});T(tl,'2035',15,{s:'Bold',x:x35,y:0});T(tl,'≈ 2056',15,{s:'Bold',x:inner,y:0,right:1});
R(tl,0,24,x35,26,BD,{tl:4,tr:0});R(tl,x35,24,inner-x35,26,'EDC4B8',{tl:0,tr:4});
T(tl,'ECDSA permitted',14,{x:10,y:28});T(tl,'ECDSA disallowed — yet today’s record must still verify',14,{x:x35+10,y:28});
T(tl,'Signed today; can be archived and forged later',14,{c:SUB,lh:19,w:x35-14,x:0,y:62});
T(tl,'NIST deadline to retire ECDSA',14,{c:SUB,lh:19,w:180,x:x35,y:62});
T(tl,'A gold ownership record must stay valid ~30 years',14,{c:SUB,lh:19,w:220,al:'RIGHT',x:inner-220,y:62});
const st2=B(c2,'HORIZONTAL',{n:'Stats',gap:12,fill:true,h:STH});
stat(st2,'< 1,200','logical qubits estimated to break blockchain elliptic curves in minutes (Google, 2026)');stat(st2,'500 ×','gas to verify one PQ signature on-chain: 1.5 M vs 3,000 for ECDSA');

// ---------- 2. SOLUTION (2 columns) ----------
const s2=B(M,'VERTICAL',{n:'2 Solution',gap:12,fill:true});
heading(s2,'2.','Proposed Solution','Separate authentication from anchoring');
const so=B(s2,'HORIZONTAL',{n:'Solution row',gap:GUT,fill:true});so.counterAxisAlignItems='MIN';
const left=B(so,'VERTICAL',{n:'Cycle column',gap:16,w:HALF});
const cy=F(left,HALF,352,'Verification cycle');const BW=230,BH=90,cols=[0,(HALF-BW)/2,HALF-BW],ROW2=262;
function step(x,y,k,v,d,on,w,h,dash){const b=B(cy,'VERTICAL',{n:k,bg:on?LG:(dash?BG:W),stroke:on?LGB:(dash?'A8A397':BD),sw:dash?2:1,dash:dash?[6,5]:null,r:12,p:10,gap:1,ai:'CENTER',jc:'CENTER',w:w||BW,h:h||BH});
 T(b,k,13,{s:'Bold',c:on?G:SUB,ls:1.5,al:'CENTER'});T(b,v,25,{f:PF,s:'Bold',lh:31,al:'CENTER'});T(b,d,14,{c:SUB,al:'CENTER',w:(w||BW)-20});b.x=x;b.y=y;return b;}
const mid=BH/2;
arrow(cy,cols[0]+BW+8,mid,cols[1]-8,mid);arrow(cy,cols[1]+BW+8,mid,cols[2]-8,mid);arrow(cy,cols[2]+BW/2,BH+8,cols[2]+BW/2,ROW2-8);
arrow(cy,cols[2]-8,ROW2+mid,cols[1]+BW+8,ROW2+mid);arrow(cy,cols[1]-8,ROW2+mid,cols[0]+BW+8,ROW2+mid);arrow(cy,cols[0]+BW/2,ROW2-8,cols[0]+BW/2,BH+8);
step(cols[0],0,'1 · SIGN','Falcon-512','on the user’s device');step(cols[1],0,'2 · VERIFY','7 checks','in the platform back-end');step(cols[2],0,'3 · EXECUTE','Contract call','state change applied',1);
step(cols[2],ROW2,'4 · BATCH','32-byte hash','joins the 60-second batch');step(cols[1],ROW2,'5 · ANCHOR','One root','per batch, written on-chain',1);step(cols[0],ROW2,'6 · PROVE','12 hashes','checked offline by the user');
step(cols[1],(ROW2+BH)/2-56,'DISPUTE · ONLY IF CHALLENGED','1.5 M gas','full Falcon check of one action, paid by the challenger',0,BW,112,1);
const built=B(left,'HORIZONTAL',{n:'Built on top',gap:10,ai:'CENTER',fill:true,h:52});T(built,'BUILT ON TOP',13,{s:'Bold',c:G,ls:1.5});
[['ERC-3643 gold token','1 token = 1 g, custodian-attested'],['ERC-4626 vault','10⁶ virtual-share offset'],['Lending engine','5-source oracle + reserve buffer']].forEach(([a,b],i)=>{if(i)T(built,'→',20,{s:'Bold',c:G});const c=B(built,'VERTICAL',{n:a,bg:W,stroke:BD,r:10,px:12,py:7,gap:1,fill:true});T(c,a,15,{s:'Bold'});T(c,b,13,{c:SUB});});

// right: Merkle batch diagram (structural facts, not a modelled chart)
const mk=card(so,{n:'Merkle batch',w:HALF,p:18,gap:10});mk.layoutSizingVertical='FILL';
T(mk,'One Merkle root anchors the whole 60-second batch',18,{s:'Bold',lh:24,fill:true});
const MW=HALF-36,MH=318;const mc=F(mk,MW,MH,'Merkle tree');
const TW=470,ly=[30,108,186,264],nodeW=[132,64,52,44],nodeH=[40,28,28,28];
const nodes=[[TW/2],[TW/4,TW*3/4],[TW/8,TW*3/8,TW*5/8,TW*7/8],[...Array(8)].map((_,i)=>TW/16+i*TW/8)];
const proof=new Set(['3-3','2-0','1-1']);const mine='3-2',pathSet=new Set(['3-2','2-1','1-0','0-0']);
for(let L=1;L<4;L++)nodes[L].forEach((x,i)=>{const px=nodes[L-1][Math.floor(i/2)];const on=pathSet.has(`${L}-${i}`);path(mc,`M ${x} ${ly[L]} L ${px} ${ly[L-1]+nodeH[L-1]/2}`,{c:on?G:BD,w:on?3:1.5});});
nodes.forEach((xs,L)=>xs.forEach((x,i)=>{const id=`${L}-${i}`,w=nodeW[L],h=nodeH[L];const r=R(mc,x-w/2,ly[L]-h/2,w,h,L===0?G:(id===mine?G:(proof.has(id)?LG:W)),{r:6,stroke:L===0||id===mine?G:(proof.has(id)?G:BD),sw:proof.has(id)?2:1.5});if(proof.has(id))r.dashPattern=[4,3];}));
T(mc,'ROOT · 32 B',13,{s:'Bold',c:W,x:TW/2,y:ly[0]-8,center:1});
T(mc,'your action',13,{s:'Bold',c:G,x:nodes[3][2],y:ly[3]+20,center:1});
T(mc,'actions in the batch (up to 4,096)',13,{c:SUB,x:TW/2,y:ly[3]+38,center:1});
const lx=TW+30;
[['4,096','actions fit in one 60-second batch'],['1 root','32 bytes on-chain per batch · 43,000 gas budget'],['12 hashes','prove any one action offline (log₂ 4,096)']].forEach(([n,d],i)=>{const y=12+i*96;T(mc,n,30,{f:PF,s:'Bold',c:G,x:lx,y});T(mc,d,14,{c:INK,lh:19,w:MW-lx,x:lx,y:y+40});});
const lg=B(mk,'HORIZONTAL',{n:'Legend',gap:18,ai:'CENTER'});
[[G,G,'your action and the root'],[LG,G,'proof hashes you download'],[W,BD,'other actions']].forEach(([f,s,l])=>{const r=B(lg,'HORIZONTAL',{n:l,gap:6,ai:'CENTER'});const q=figma.createRectangle();r.appendChild(q);q.resize(14,14);q.cornerRadius=3;q.fills=S(f);q.strokes=S(s);q.strokeWeight=1.5;T(r,l,13,{c:SUB});});

// ---------- 3. ARCHITECTURE ----------
const s3=B(M,'VERTICAL',{n:'3 Architecture',gap:12,fill:true});
heading(s3,'3.','System Architecture');
const ar=B(s3,'HORIZONTAL',{n:'Stages',fill:true,h:196});ar.counterAxisAlignItems='MIN';
const LINK=104,STW=(CW-3*LINK)/4;
function stage(k,title,sub,items,net){const c=card(ar,{n:title,p:16,gap:10,bg:net?LG:W,stroke:net?LGB:BD,w:STW});c.layoutSizingVertical='FILL';
 const hd=B(c,'VERTICAL',{n:'Head',gap:0,fill:true});T(hd,k,13,{s:'Bold',c:G,ls:1.5});T(hd,title,22,{s:'Bold',lh:28});T(hd,sub,15,{c:SUB});
 const r=wrapRow(c,8);items.forEach(s=>chip(r,s,{bg:net?W:CHIP}));}
function link(label){const a=B(ar,'VERTICAL',{n:'link',gap:6,ai:'CENTER',jc:'CENTER',w:LINK});a.layoutSizingVertical='FILL';T(a,label,13,{c:SUB,al:'CENTER',lh:17,w:LINK-12});const cv=F(a,72,12,'arrow');arrow(cv,4,6,70,6);}
stage('1 · USER DEVICE','Client apps','React + WebAssembly',['Investor app','Falcon-512 signer','Key never leaves device','Custodian console']);link('PQ-signed envelope');
stage('2 · PLATFORM SERVICES','Off-chain services','NestJS on Node.js',['PQ verifier · 7 checks','Oracle · 5 feeds','Risk engine','Batcher · root / 60 s']);link('contract call + Merkle root');
stage('3 · SMART CONTRACTS','On-chain logic','Solidity, immutable',['PQ key registry','ERC-3643 + ERC-4626','Lending pool','Falcon verifier']);link('settled & recorded');
stage('4 · NETWORK','Arbitrum Sepolia','Ethereum-secured rollup',['Balances & loans','One 32-byte root / 60 s','Public, permanent record'],1);

// ---------- 4 + 5. CORE AND RESULTS (3 columns) ----------
const s45=B(M,'HORIZONTAL',{n:'4-5 Core and Results',gap:GUT,fill:true});s45.counterAxisAlignItems='MIN';
const CARDH=410;
const c4=B(s45,'VERTICAL',{n:'4 Core',gap:12,w:THIRD});heading(c4,'4.','Post-Quantum Crypto Core');
const k4=card(c4,{n:'Core card',p:20,gap:12});k4.resize(THIRD,CARDH);k4.layoutSizingVertical='FIXED';
const ki=T(k4,'One NIST algorithm per job, from vetted reference code, in one Rust library (native + WebAssembly). No cryptography written in-house.',16,{lh:22,fill:true});ki.setRangeFontName(ki.characters.indexOf('No crypto'),ki.characters.length,{family:'DM Sans',style:'Bold'});
const tbl=B(k4,'VERTICAL',{n:'Algorithms',fill:true});
// sizes are those produced by pq-core (measured run, 16 Nov 2026)
[['User actions','Falcon-512','666-byte signature, the smallest'],['Reserve reports','ML-DSA-65','3,309-byte signature, higher security'],['Service signing','ML-DSA-44','2,420-byte signature, fast'],['Offline root key','SLH-DSA-SHA2-128s','7,856-byte signature, hash-based'],['Key exchange','ML-KEM-768 / 1024','1,088 / 1,568-byte ciphertext']].forEach(([a,b,c],i,arr)=>{
 const r=B(tbl,'HORIZONTAL',{n:a,gap:12,ai:'CENTER',fill:true,h:48});r.strokes=S(GRID);r.strokeTopWeight=1;r.strokeBottomWeight=i===arr.length-1?1:0;r.strokeLeftWeight=0;r.strokeRightWeight=0;
 T(r,a,15,{s:'Bold',w:140});const v=B(r,'VERTICAL',{n:'algo',fill:true});T(v,b,16,{s:'Bold',c:G});T(v,c,13,{c:SUB});});
const sp0=B(k4,'VERTICAL',{n:'spacer',fill:true});sp0.layoutGrow=1;
const trust=B(k4,'HORIZONTAL',{n:'Trust chain',gap:8,ai:'CENTER',fill:true});T(trust,'Trust chain:',14,{s:'Bold'});
['SLH-DSA root','ML-DSA-65','Falcon-512'].forEach((s,i)=>{if(i)T(trust,'→',16,{s:'Bold',c:G});chip(trust,s,{bg:i===2?G:LG,c:i===2?W:G,s:'Bold',size:13,r:12});});

const c5=B(s45,'VERTICAL',{n:'5 Results',gap:12,fill:true});heading(c5,'5.','Results','Measured on our implementation');
const r5=B(c5,'HORIZONTAL',{n:'Results cards',gap:GUT,fill:true,h:CARDH});
// 5a: real measured speed of pq-core
const k5=card(r5,{n:'Measured speed',p:20,gap:12,w:THIRD});k5.layoutSizingVertical='FILL';
T(k5,'Time to sign and verify one message',18,{s:'Bold',lh:24,fill:true});
const lg5=B(k5,'HORIZONTAL',{n:'Legend',gap:16,ai:'CENTER'});[[G,'sign'],[MG,'verify']].forEach(([c,l])=>{const r=B(lg5,'HORIZONTAL',{n:l,gap:6,ai:'CENTER'});const q=figma.createRectangle();r.appendChild(q);q.resize(14,14);q.cornerRadius=3;q.fills=S(c);T(r,l,13,{c:SUB});});T(lg5,'log scale, milliseconds',13,{c:SUB});
const sch=B(k5,'VERTICAL',{n:'Speed bars',gap:10,fill:true});
const IN5=THIRD-40,LBW=128,BMAX=IN5-LBW-12-74,lo=Math.log10(0.05),hi=Math.log10(3000),bw=v=>Math.max(4,(Math.log10(v)-lo)/(hi-lo)*BMAX);
const fmt=v=>v>=100?v.toLocaleString('en-US',{maximumFractionDigits:0}):v.toFixed(2);
[['Falcon-512',8.18,0.09],['ML-DSA-44',0.55,0.19],['ML-DSA-65',1.00,0.31],['SLH-DSA-128s',2058,1.99]].forEach(([a,s,v])=>{const r=B(sch,'HORIZONTAL',{n:a,gap:12,ai:'CENTER',fill:true});T(r,a,14,{s:'Bold',c:a==='Falcon-512'?G:INK,w:LBW});
 const bb=B(r,'VERTICAL',{n:'bars',gap:4,fill:true});[[s,G],[v,MG]].forEach(([x,c])=>{const q=B(bb,'HORIZONTAL',{n:'bar',gap:8,ai:'CENTER'});const rr=figma.createRectangle();q.appendChild(rr);rr.resize(bw(x),14);rr.cornerRadius=3;rr.fills=S(c);T(q,fmt(x)+' ms',13,{s:'Bold'});});});
const sp5=B(k5,'VERTICAL',{n:'spacer',fill:true});sp5.layoutGrow=1;
const ms=B(k5,'HORIZONTAL',{n:'Callout',bg:LG,r:10,px:14,py:10,gap:12,ai:'CENTER',fill:true});T(ms,'< 2 ms',32,{f:PF,s:'Bold',c:G,lh:36});T(ms,'to verify any signature, so the 7 back-end checks add no noticeable delay',14,{lh:19,fill:true});
T(k5,'pq-core native build · Intel i7-8565U · median of repeated runs · 16 Nov 2026',12,{c:SUB,fill:true});
// 5b: health-factor bands (design specification)
const k6=card(r5,{n:'Health factor',p:20,gap:12,w:THIRD});k6.layoutSizingVertical='FILL';
T(k6,'Borrower protection by health factor (HF)',18,{s:'Bold',lh:24,fill:true});
const hw=THIRD-40;const hb=F(k6,hw,52,'HF bar');const segs=[[58,'D98F7E'],[58,'E9B9A9'],[58,'EFD3AE'],[173,'E9E1AE']];let hx=0;const sc2=hw/520;
segs.forEach(([w,c],i)=>{R(hb,hx,0,w*sc2,28,c,i===0?{tl:6,tr:0}:{});hx+=w*sc2;});R(hb,hx,0,hw-hx,28,'BFDDC6',{tl:0,tr:6});
let tx=0;['0.90','0.95','1.00','1.15'].forEach((l,i)=>{tx+=segs[i][0]*sc2;T(hb,l,13,{c:SUB,x:tx,y:32,center:1});});
const hl=B(k6,'VERTICAL',{n:'Bands',gap:6,fill:true});
[['≥ 1.15','BFDDC6','Healthy · borrowing allowed'],['1.00 – 1.15','E9E1AE','New borrowing frozen · 6-hour top-up window'],['0.95 – 1.00','EFD3AE','Reserve buffer covers the shortfall · 6-hour grace'],['0.90 – 0.95','E9B9A9','At most 50 % liquidated · bonus 5 % → 3 %'],['< 0.90','D98F7E','Full closure of the position']].forEach(([k,c,d])=>{const r=B(hl,'HORIZONTAL',{n:k,gap:12,ai:'CENTER',fill:true,h:40});const pl=B(r,'HORIZONTAL',{n:'pill',bg:c,r:6,py:6,jc:'CENTER',w:108});T(pl,k,14,{s:'Bold',al:'CENTER'});T(r,d,14,{lh:19,fill:true});});
const sp6=B(k6,'VERTICAL',{n:'spacer',fill:true});sp6.layoutGrow=1;
T(k6,'HF = collateral value × 75 % ÷ debt  (design specification)',13,{c:SUB});

// ---------- 6. OUTCOMES ----------
const s6=B(M,'VERTICAL',{n:'6 Outcomes',gap:12,fill:true});heading(s6,'6.','Expected Outcomes','Design targets, measured against an identical ECDSA-only build');
const LABW=200,TILEW=(CW-LABW-4*10)/4;
function orow(lab,sub,tiles){const r=B(s6,'HORIZONTAL',{n:lab,gap:10,fill:true,h:116});const l=B(r,'VERTICAL',{n:'Label',bg:DK,r:12,p:16,gap:4,jc:'CENTER',w:LABW});l.layoutSizingVertical='FILL';T(l,lab,20,{s:'Bold',c:W,lh:24});T(l,sub,14,{c:'C9CFCB'});
 tiles.forEach(([n,d,t])=>{const c=B(r,'VERTICAL',{n,bg:W,stroke:BD,r:12,px:16,py:12,gap:2,w:TILEW});c.layoutSizingVertical='FILL';T(c,n,32,{f:PF,s:'Bold',c:G,lh:38});T(c,d,15,{lh:20,fill:true});const tt=T(c,t,14,{c:MUT,lh:20,fill:true});tt.setRangeFontName(0,6,{family:'DM Sans',style:'Bold'});});}
orow('6.1 Security','addresses Problem 1.2',[['≈ 43,000 gas','per 60-s batch of up to 4,096 actions','Today: 1,500,000 gas per action'],['n ≥ 15','actions per batch to beat ECDSA’s cost','Today: 500× the cost of ECDSA'],['Quantum-safe','ownership records on an EVM network','Today: ECDSA, retired after 2035'],['12 hashes','offline proof of inclusion, no trust','Today: trust the operator’s database']]);
orow('6.2 Financial','addresses Problem 1.1',[['PKR 1,000','minimum: 1 token = 1 g of gold','Today: $5 M minimum'],['10⁶ ×','attack cost: ~PKR 1 bn per PKR 1,000','Today: 1 : 1'],['6 h · 50 %','grace on a dip; at most half liquidated','Today: liquidated on a 3 % move'],['5 sources','median of ≥ 3, within 10 % of the 30-min average','Today: one feed, $114 M lost']]);

// ---------- SDGs (same label column + 5 equal tiles as the outcome rows) ----------
const sdg=B(M,'HORIZONTAL',{n:'SDG band',gap:10,fill:true,h:116});
const sdl=B(sdg,'VERTICAL',{n:'Label',bg:G,r:12,p:16,gap:4,jc:'CENTER',w:LABW});sdl.layoutSizingVertical='FILL';T(sdl,'UN Sustainable Development Goals',18,{s:'Bold',c:W,lh:23,w:LABW-32});
const SDGW=(CW-LABW-5*10)/5;
// Official SDG colours; replace any tile with the official UN icon if preferred.
[['1','No poverty','fractional gold from PKR 1,000','E5243B'],['5','Gender equality','low-minimum mobile account','FF3A21'],['8','Decent work & economic growth','banking access in one platform','A21942'],['9','Industry, innovation & infrastructure','asset-backed micro-credit','FD6925'],['16','Peace, justice & strong institutions','every action verifiable by anyone','00689D']].forEach(([n,l,why,c])=>{
 const t=B(sdg,'HORIZONTAL',{n:'SDG '+n,bg:c,r:12,p:14,gap:12,ai:'CENTER',w:SDGW});t.layoutSizingVertical='FILL';T(t,n,44,{s:'Bold',c:W,lh:48,w:58});const tx2=B(t,'VERTICAL',{n:'txt',gap:3,fill:true});T(tx2,l.toUpperCase(),12,{s:'Bold',c:W,lh:15,ls:0.5,fill:true});T(tx2,why,13,{c:W,lh:17,fill:true});});

// ---------- technology logos (spread across the full width) ----------
const ts=B(M,'HORIZONTAL',{n:'Technology',gap:10,ai:'CENTER',fill:true,jc:'SPACE_BETWEEN'});T(ts,'BUILT WITH',13,{s:'Bold',c:G,ls:1.5});
if(techChips.length){const seen=new Set();for(const c of techChips){if(seen.has(c.name))continue;seen.add(c.name);ts.appendChild(c);c.layoutSizingHorizontal='HUG';}}
else ['Solidity','Foundry','Rust','WebAssembly','NestJS','Node.js','React','PostgreSQL','Redis','Arbitrum Sepolia'].forEach(s=>chip(ts,s,{bg:W,stroke:BD}));
holder.remove();

// ---------- fit to A1 ----------
M.layoutSizingVertical='HUG';C.layoutSizingVertical='HUG';const natural=C.height;
C.resize(1800,2548);C.layoutSizingHorizontal='FIXED';C.layoutSizingVertical='FIXED';M.layoutSizingVertical='FILL';
return {clone:C.id,natural,fits:natural<=2548,sections:M.children.map(k=>[k.name,Math.round(k.height)])};
