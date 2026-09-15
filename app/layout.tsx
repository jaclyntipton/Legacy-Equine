import type { Metadata } from "next"; import "./globals.css"; import "./theme.css"; import "./profile-fix.css"; import "./forms.css";
export const metadata:Metadata={title:"Legacy Equine — Breed Your Legacy",description:"An original browser horse breeding simulation."};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
