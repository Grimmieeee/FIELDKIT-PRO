export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/api/visits') {
      if(request.method !== 'GET') return new Response(null,{status:405});
      try {
        const upstream = await fetch('https://hits.sh/sexypowershell.com/field-kit-7c84e192.svg?label=Visits', {signal:AbortSignal.timeout(8000)});
        if(!upstream.ok) throw new Error('Counter unavailable');
        const svg = await upstream.text();
        const match = svg.match(/aria-label="Visits: ([0-9][0-9,]*)"/);
        if(!match) throw new Error('Invalid counter response');
        return Response.json({count:match[1]}, {headers:{'Cache-Control':'no-store'}});
      } catch {return Response.json({error:'Counter unavailable'},{status:502,headers:{'Cache-Control':'no-store'}});}
    }
    if(!['GET','HEAD'].includes(request.method))return new Response(null,{status:405});
    const path = url.pathname === '/' ? '/index.html' : url.pathname;
    const file = FILES[path];
    if(!file)return new Response('Not found',{status:404});
    const bytes = Uint8Array.from(atob(file[1]), c=>c.charCodeAt(0));
    return new Response(request.method==='HEAD'?null:bytes,{headers:{'Content-Type':file[0],'Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'}});
  }
};
