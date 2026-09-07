const fs=require('fs');const http=require('http');
const code=fs.readFileSync('_gen_goblin.gd','utf8');
const payload=JSON.stringify({code,project_path:'Test-ARPG'});
const data=Buffer.from(payload,'utf8');
const req=http.request({host:'localhost',port:5302,path:'/api/execute',method:'POST',
  headers:{'Authorization':'Bearer 995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7',
  'Content-Type':'application/json','Content-Length':data.length}},res=>{
  let b='';res.on('data',c=>b+=c);res.on('end',()=>console.log(b));});
req.on('error',e=>console.error('ERR',e.message));req.write(data);req.end();
