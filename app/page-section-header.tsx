import type {ReactNode} from "react";
import "@/app/page-section-header.css";

type HeaderVariant="page"|"admin"|"detail";

export function PageSectionHeader({eyebrow,title,subtitle,primaryAction,secondaryAction,className="",level=1,variant="page"}:{eyebrow:string;title:ReactNode;subtitle?:ReactNode;primaryAction?:ReactNode;secondaryAction?:ReactNode;className?:string;level?:1|2;variant?:HeaderVariant}){
 const Heading=level===1?"h1":"h2";
 return <header className={`page-section-header page-section-header--${variant}${className?` ${className}`:""}`}>
  <div className="page-section-header__copy"><p className="eyebrow">{eyebrow}</p><Heading>{title}</Heading>{subtitle&&<p className="page-section-header__subtitle">{subtitle}</p>}</div>
  {(primaryAction||secondaryAction)&&<div className="page-section-header__actions">{secondaryAction&&<div className="page-section-header__secondary">{secondaryAction}</div>}{primaryAction&&<div className="page-section-header__primary">{primaryAction}</div>}</div>}
 </header>;
}

export function SectionHeading({eyebrow,title,subtitle,className="",level=2}:{eyebrow?:string;title:ReactNode;subtitle?:ReactNode;className?:string;level?:2|3}){
 const Heading=level===2?"h2":"h3";
 return <div className={`section-heading${className?` ${className}`:""}`}>{eyebrow&&<p className="eyebrow">{eyebrow}</p>}<Heading>{title}</Heading>{subtitle&&<p>{subtitle}</p>}</div>;
}
