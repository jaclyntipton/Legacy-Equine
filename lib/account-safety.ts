export function parseCalendarDate(value:string){
 const match=/^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
 if(!match)return null;
 const year=Number(match[1]),month=Number(match[2]),day=Number(match[3]);
 const date=new Date(Date.UTC(year,month-1,day));
 return date.getUTCFullYear()===year&&date.getUTCMonth()===month-1&&date.getUTCDate()===day?date:null;
}

export function isAtLeast18(value:string,today=new Date()){
 const dob=parseCalendarDate(value);
 if(!dob)return false;
 const cutoff=new Date(Date.UTC(today.getUTCFullYear()-18,today.getUTCMonth(),today.getUTCDate()));
 return dob<=cutoff;
}
