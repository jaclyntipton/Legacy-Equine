import type { ReactNode } from "react";
import "@/app/page-section-header.css";

export function PageSectionHeader({
  eyebrow,
  title,
  subtitle,
  primaryAction,
  secondaryAction,
  className = "",
  level = 1,
  detail = false,
}: {
  eyebrow: string;
  title: ReactNode;
  subtitle?: ReactNode;
  primaryAction?: ReactNode;
  secondaryAction?: ReactNode;
  className?: string;
  level?: 1 | 2;
  detail?: boolean;
}) {
  const Heading = level === 1 ? "h1" : "h2";
  return (
    <header className={`page-section-header${detail ? " page-section-header--detail" : ""}${className ? ` ${className}` : ""}`}>
      <div className="page-section-header__copy">
        <p className="eyebrow">{eyebrow}</p>
        <Heading>{title}</Heading>
        {subtitle && <p className="page-section-header__subtitle">{subtitle}</p>}
      </div>
      {(primaryAction || secondaryAction) && (
        <div className="page-section-header__actions">
          {secondaryAction && <div className="page-section-header__secondary">{secondaryAction}</div>}
          {primaryAction && <div className="page-section-header__primary">{primaryAction}</div>}
        </div>
      )}
    </header>
  );
}
