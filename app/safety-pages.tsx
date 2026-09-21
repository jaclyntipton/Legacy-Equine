"use client";
import Link from "next/link";
import "@/app/safety-pages.css";
export function SafetyPages({ page }: { page: "privacy" | "standards" }) {
  return (
    <div className="safetypage">
      <Link className="back" href="/support">
        ← Help &amp; Support
      </Link>
      {page === "privacy" ? (
        <>
          <header>
            <p className="eyebrow">PLAYER PRIVACY</p>
            <h1>Privacy &amp; Safety</h1>
            <p>
              A plain-language guide to the information Legacy Equine uses and
              how we protect it.
            </p>
          </header>
          <section className="panel">
            <h2>What we collect</h2>
            <p>
              Legacy Equine collects your private first name, last name, and
              date of birth, along with the email and authentication information
              needed to operate your account. Your public game
              identity—username, Stable name, and account number—is separate.
            </p>
            <h2>Why we collect it</h2>
            <p>
              Your date of birth enforces Legacy Equine’s current 18+
              requirement and supports account and community safety. A
              self-entered date of birth is an age gate, not formal identity
              verification. Private names support legitimate account
              administration and safety work; they are not used as public
              identity.
            </p>
            <h2>What other players can see</h2>
            <p>
              Other players do not see your private first name, last name, date
              of birth, email, or authentication information. These are not
              displayed on Public Profiles, Public Stables, Mailbox, Community
              Chat, player search, Marketplace, or Profession businesses.
            </p>
            <h2>Who may access private information</h2>
            <p>
              Only specifically authorized account and safety administrators may
              access private account information when required for legitimate
              administration. Access and corrections are audited.
            </p>
            <h2>Your questions and corrections</h2>
            <p>
              Date-of-birth and private-name corrections are handled through{" "}
              <Link href="/support">Help &amp; Support → Contact Admin</Link>.
              Do not post private identity information in Chat or Mailbox.
            </p>
          </section>
          <section className="policyreview">
            <h2>Formal policies</h2>
            <p>
              Formal Privacy Policy, Terms of Service, and Data Retention /
              Deletion Policy language is pending Owner/legal review. This page
              explains the product’s current implemented behavior and is not a
              substitute for those reviewed policies.
            </p>
          </section>
        </>
      ) : (
        <>
          <header>
            <p className="eyebrow">SAFE, RESPECTFUL, HORSE-FOCUSED</p>
            <h1>Community Standards</h1>
            <p>
              Legacy Equine is an 18+ community, but explicit or harmful conduct
              is not permitted.
            </p>
          </header>
          <section className="panel">
            <h2>Not permitted</h2>
            <ul>
              <li>Sexual or explicit content and sexual solicitation</li>
              <li>Harassment, bullying, intimidation, or targeted abuse</li>
              <li>Threats or encouragement of violence</li>
              <li>Encouraging or instructing self-harm</li>
              <li>Hateful or dehumanizing abuse</li>
              <li>Predatory or grooming-like behavior</li>
              <li>Doxxing, credential sharing, or private-information abuse</li>
              <li>Scams, malicious solicitation, or disruptive spam</li>
            </ul>
            <h2>Automated safety checks</h2>
            <p>
              Player messages and public text may be checked before delivery or
              publication. Depending on risk, content may require editing, be
              blocked, or be sent for authorized safety review. A safety match
              does not automatically ban an account.
            </p>
            <h2>If you need help</h2>
            <p>
              Block a player and report the relevant message or content when
              available. For concerns, appeals, or a player in distress, use{" "}
              <Link href="/support">Help &amp; Support → Contact Admin</Link>.
              Someone seeking help is not treated the same as someone
              encouraging harm.
            </p>
          </section>
        </>
      )}
    </div>
  );
}
