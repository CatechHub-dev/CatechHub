// nav.js — highlight active nav item based on current URL
(function(){
  function normalize(href){
    try{
      const u = new URL(href, location.origin);
      let p = u.pathname.replace(/index\.html$/,'');
      if(!p.endsWith('/')) p = p + '/';
      return u.origin + p + (u.hash || '');
    }catch(e){
      return href;
    }
  }

  const current = (function(){
    const p = location.pathname.replace(/index\.html$/,'');
    return location.origin + (p.endsWith('/')? p : p + '/') + (location.hash || '');
  })();

  document.addEventListener('DOMContentLoaded', ()=>{
    const links = document.querySelectorAll('.nav-menu a');
    const currentBase = current.split('#')[0];
    const currentHash = location.hash || '';
    links.forEach(a=>{
      try{
        const aNorm = normalize(a.href);
        const aBase = aNorm.split('#')[0];
        const aHash = a.hash || '';
        const isDefaultHome = !currentHash && (aHash === '' || aHash === '#home');
        if(aBase === currentBase && (aHash === currentHash || isDefaultHome)){
          a.classList.add('active');
        } else {
          a.classList.remove('active');
        }
      }catch(_){/* ignore */}
    });
  });
})();
