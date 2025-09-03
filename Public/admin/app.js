async function post(url, body){
  const res = await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body: body? JSON.stringify(body): undefined});
  if(!res.ok){
    let txt = await res.text(); try{txt = JSON.parse(txt).message}catch{}
    throw new Error(`${res.status} ${txt}`)
  }
  return res
}

async function refresh(){
  const limit = parseInt(document.getElementById('limit').value)||20;
  const res = await fetch(`/api/posts?page=1`);
  const data = await res.json();
  const list = document.getElementById('posts');
  list.innerHTML = '';
  const items = data.items.slice(0,limit);
  for(const p of items){
    const li = document.createElement('li');
    const dt = new Date(p.createdAt);
    li.innerHTML = `<div>${p.author.displayName}: ${p.text}</div><div class="meta">${dt.toISOString()} • likes ${p.likeCount} • ${p.id}</div>`;
    list.appendChild(li);
  }
}

document.getElementById('btn-refresh').onclick = refresh;

document.getElementById('btn-apply-faults').onclick = async ()=>{
  try{
    const latencyMs = parseInt(document.getElementById('latency').value)||0;
    const errorRate = parseInt(document.getElementById('errorRate').value)||0;
    const rateLimit = document.getElementById('rateLimit').checked;
    await post('/admin/faults',{latencyMs,errorRate,rateLimit});
    document.getElementById('faults-status').textContent = 'OK';
  }catch(e){document.getElementById('faults-status').textContent = e.message}
}

document.getElementById('btn-seed').onclick = async ()=>{
  try{ await post('/admin/seed'); await refresh(); }catch(e){ alert(e.message) }
}

document.getElementById('btn-reset').onclick = async ()=>{
  try{ await post('/admin/reset'); await refresh(); }catch(e){ alert(e.message) }
}

document.getElementById('btn-spawn').onclick = async ()=>{
  const authorId = document.getElementById('spawn-author').value.trim();
  const text = document.getElementById('spawn-text').value.trim();
  const imageUrl = document.getElementById('spawn-image').value.trim()||null;
  try{ await post('/admin/spawn',{authorId,text,imageUrl}); document.getElementById('spawn-status').textContent='Posted'; await refresh(); }
  catch(e){ document.getElementById('spawn-status').textContent = e.message }
}

refresh();

