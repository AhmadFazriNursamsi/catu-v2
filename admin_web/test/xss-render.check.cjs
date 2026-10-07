const fs=require('fs'),vm=require('vm');
const X='<img src=x onerror=alert(1)>"\'';
const ctx={console,window:{addEventListener(){},location:{hostname:'localhost',protocol:'http:',origin:'http://localhost'}},navigator:{userAgent:'x'},document:{getElementById:()=>null,querySelector:()=>null,addEventListener(){}},localStorage:{getItem:()=>null,setItem(){}},setTimeout,fetch:()=>Promise.resolve({}),location:{}};
ctx.globalThis=ctx;vm.createContext(ctx);
const load=f=>vm.runInContext(fs.readFileSync(f,'utf8'),ctx,{filename:f});
const fields=new Proxy({},{get:(t,k)=>typeof k==='string'?(/_id$|^id$|year|total|count/.test(k)?1:X):undefined});
const order={id:1,status:'CONFIRMED',order_number:X,category_name:X,pemohon_name:X,paroki_name:X,location_name:X,address_detail:X,notes:'a: '+X+' | '+X,keuskupan_name:X,lingkungan_name:X,urgency_name:X,acceptedRomoName:X,items:[{id:1,itemName:X,item_name:X,locationName:X,status:'PENDING',scheduledDate:'2030-01-01'}],scheduled_date:'2030-01-01'};
const user=new Proxy({id:1,role_code:'UMAT',account_status:'APPROVED'},{get:(t,k)=>k in t?t[k]:(typeof k==='string'?(/_id$|year/.test(k)?1:X):undefined)});
for(const f of ['config.js','services/html-escape.js','services/approval-helpers.js']) { try{load(__dirname+'/../js/'+f)}catch(e){console.log('load',f,e.message)} }
const names=[];
for(const f of ['views/orders.js','views/umat.js','views/romo.js','views/pengurus.js','views/approvals.js','views/master-table.js','modals/user-profile-modal.js','modals/user-edit-modal.js','logs/activity-logs.js','views/master-columns.js','views/master.js','modals/master-modal.js','modals/combobox.js','modals/master-delete-modal.js','views/layout.js','views/overview.js']){try{load(__dirname+'/../js/'+f)}catch(e){console.log('load',f,e.message)}}
const S=vm.runInContext('state',ctx);
Object.assign(S,{orders:[order],activeOrderDetail:order,orderSearch:X,orderStatusFilter:'ALL',orderCategoryFilter:'ALL',users:[user],umatSearch:X,romoParokiSearch:X,romoOrdoSearch:X,pengurusSearch:X,koordinatorSearch:X,umatPendatangSearch:X,approvalsSearch:X,paroki:[{id:1,name:X}],currentUser:user});
const out=[];
const call=(fn,...a)=>vm.runInContext(fn+'('+a.map((_,i)=>'__a'+i).join(',')+')',Object.assign(ctx,Object.fromEntries(a.map((v,i)=>['__a'+i,v]))));
for(const fn of ['renderOrdersTab','renderOrderDetailModal']){try{out.push([fn,call(fn)])}catch(e){console.log('ERR',fn,e.message)}}
for(const fn of ['renderUmatTab','renderRomoParokiTab','renderRomoOrdoTab','renderPengurusTab','renderApprovalsTab','renderUmatPendatangTab','renderPengurusLingkunganTab']){ if(ctx[fn]){try{out.push([fn,call(fn)])}catch(e){console.log('ERR',fn,e.message.slice(0,80))}}}
for(const fn of ['renderUmatTable','renderRomoParokiTable','renderRomoOrdoTable','renderPengurusTable','renderKoordinatorTable','renderUmatPendatangTable']){ if(vm.runInContext('typeof '+fn,ctx)==='function'){try{out.push([fn,call(fn,[user])])}catch(e){console.log('ERR',fn,e.message.slice(0,80))}}}
const log={id:X,userName:X,description:X,ipAddress:X,userAgent:X,targetEntity:X,action:X,metadata:{a:X},createdAt:'2030-01-01T00:00:00Z'};
Object.assign(S,{activeUserProfile:user,editingUser:user,editUser:user,activityLogs:[log],activityLogsData:[log],logs:[log],activeActivityLog:log,activityLogDetail:log,selectedActivityLog:log,masterModalError:X,editFormError:X,loginError:X,masterDelete:{name:X,errorMessage:X,id:1},deleteConfirm:{name:X,errorMessage:X,id:1,sub:'paroki'},activeDelete:{name:X,errorMessage:X,id:1,sub:'paroki'}});
for(const [fn,args] of [['renderUserProfileModal',[]],['renderEditUserModal',[]],['renderActivityLogsTable',[]],['renderActivityLogDetailModal',[]],['renderDeleteConfirmModal',[]],['renderMasterModalFields',['paroki',user]],['renderMasterModalFields',['ordo',user]],['renderMasterModalFields',['kategori',user]],['renderMasterTableRow',['paroki',user,0]],['renderMasterTableRow',['keuskupan',user,0]],['renderMasterTableRow',['lingkungan',user,0]],['renderMasterTableRow',['ordo',user,0]],['renderCustomCombobox',[{name:'n',id:'i',options:[{id:X,name:X,subtext:X,code:X}],selectedValue:X,placeholder:X,onSelectCallback:'f'}]]]){ if(vm.runInContext('typeof '+fn,ctx)==='function'){try{out.push([fn,call(fn,...args)])}catch(e){console.log('ERR',fn,e.message.slice(0,90))}}}
let bad=0;
for(const [fn,h] of out){const m=h.match(/<img src=x onerror/g);if(m){bad++;console.log(fn,"RAW",m.length)}}
console.log(out.length+' tampilan dirender, '+bad+' mengandung HTML mentah');process.exit(bad||out.length<20?1:0)
