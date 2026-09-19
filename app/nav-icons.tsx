import type {ReactNode,SVGProps} from "react";
type IconName="news"|"barn"|"store"|"round-pen"|"trophy"|"sale-tag"|"toolbox"|"bulletin"|"coin"|"heart";
const paths:Record<IconName,ReactNode>={
 news:<><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 8h5v4H7zM15 8h2m-2 4h2M7 16h10"/></>,
 barn:<><path d="M3 10 12 3l9 7v11H3Z"/><path d="M7 21v-9h10v9M7 12l5 4 5-4M12 16v5"/></>,
 store:<><path d="M4 10v10h16V10M3 9l2-5h14l2 5"/><path d="M3 9c0 2 3 2 3 0 0 2 3 2 3 0 0 2 3 2 3 0 0 2 3 2 3 0 0 2 3 2 3 0M8 20v-6h8v6"/></>,
 "round-pen":<><circle cx="12" cy="12" r="9"/><path d="M5 16c4 2 10 2 14 0M6 18v-4m4 6v-3m4 3v-3m4 1v-4"/><path d="M8.5 12.5c1-3 2.5-4.5 5-4l2-2 .5 3 2 1-2 1.5-1 3h-2l-1-2-2 1Z"/></>,
 trophy:<><path d="M8 4h8v5a4 4 0 0 1-8 0Z"/><path d="M8 6H4v2a4 4 0 0 0 4 4m8-6h4v2a4 4 0 0 1-4 4M12 13v4m-4 3h8m-6-3h4"/></>,
 "sale-tag":<><path d="m4 12 8-8h7v7l-8 8Z"/><circle cx="16" cy="7" r="1"/><path d="M8 14h4m-2-2v4"/></>,
 toolbox:<><path d="M3 9h18v11H3ZM8 9V6h8v3M3 13h18M10 12v3h4v-3"/></>,
 bulletin:<><rect x="3" y="4" width="18" height="15" rx="2"/><path d="M8 19v2m8-2v2M7 9h4m2 5h4"/><circle cx="8" cy="7" r="1"/><circle cx="16" cy="11" r="1"/></>,
 coin:<><circle cx="12" cy="12" r="9"/><path d="M15 8.5c-.7-.7-1.7-1-3-1-1.7 0-3 .8-3 2s1 1.8 3 2.5 3 1.3 3 2.5-1.3 2-3 2c-1.3 0-2.5-.4-3.2-1.2M12 5.5v13"/></>,
 heart:<path d="M20 8.5c0 5-8 10-8 10s-8-5-8-10A4.5 4.5 0 0 1 12 5.7 4.5 4.5 0 0 1 20 8.5Z"/>,
};
export function NavIcon({name,...props}:{name:IconName}&SVGProps<SVGSVGElement>){return <svg className="navicon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false" {...props}>{paths[name]}</svg>}
