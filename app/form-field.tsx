import type { ReactNode } from "react";

type FormFieldProps = {
  id: string;
  label: string;
  children: ReactNode;
  helper?: ReactNode;
  className?: string;
};

export function FormField({ id, label, children, helper, className = "" }: FormFieldProps) {
  return (
    <div className={`form-field ${className}`.trim()}>
      <label htmlFor={id}>{label}</label>
      {children}
      {helper ? <small className="form-helper">{helper}</small> : null}
    </div>
  );
}
