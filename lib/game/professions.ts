export const CERTIFICATION_LEVELS=[
 {level:1,name:"Basic",requiredServices:0},
 {level:2,name:"Proficient",requiredServices:10},
 {level:3,name:"Advanced",requiredServices:25},
 {level:4,name:"Professional",requiredServices:50},
] as const;

export function scoreCertification(correct:number,total:number,passingScore=80){
 if(total<=0||correct<0||correct>total)throw new Error("Invalid certification result");
 const score=Math.round(correct/total*10000)/100;
 return{score,passed:score>=passingScore};
}
export function qualifyingCredit(clientServices:number,selfServices:number,selfWeight=.5){return clientServices+selfServices*selfWeight}
export function validateServicePrice(price:number,min:number,max:number){return Number.isInteger(price)&&price>=min&&price<=max}
export function effectiveStat(base:number,development=0,tack=0,...temporary:number[]){return base+development+tack+temporary.reduce((sum,n)=>sum+n,0)}

