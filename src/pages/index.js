import clsx from 'clsx';
import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import PromoVideo from '@site/src/components/PromoVideo';
import styles from './index.module.css';

const facts = ['user@corp.example', 'IP · geo · ASN', 'brute-force history', 'blocklists (RBL)', 'LDAP attributes', 'MFA state'];

const decisions = [
  {verdict: 'ALLOW', tone: styles.allow, obligations: 'step-up MFA · audit'},
  {verdict: 'DENY', tone: styles.deny, obligations: 'rate-limit source · audit'},
  {verdict: 'TEMPFAIL', tone: styles.tempfail, obligations: 'retry later · backend degraded'},
];

const entryPoints = [
  {
    title: 'Mail authentication',
    tags: 'IMAP · POP3 · SMTP',
    description: 'Dovecot, Postfix and Nginx mail proxies ask Nauthilus before a session starts, so every mail login follows the same rules.',
    to: '/docs/examples/dovecot-lua',
  },
  {
    title: 'Native identity provider',
    tags: 'OIDC · SAML 2.0 · WebAuthn',
    description: 'Browser sign-in, consent and MFA for your web applications, with the policy engine deciding on every step.',
    to: '/docs/configuration/idp/oidc',
  },
  {
    title: 'HTTP services & APIs',
    tags: 'REST · gRPC · Policy API',
    description: 'Reverse proxies and web apps authenticate over HTTP or gRPC, and any other service can ask the generic Policy API for a decision.',
    to: '/docs/guides/generic-policy-api',
  },
  {
    title: 'Distributed edges',
    tags: 'gRPC identity proxy',
    description: 'Edge instances forward identity and policy questions to a central authority, so remote sites decide like headquarters.',
    to: '/docs/configuration/identity-proxy',
  },
];

function HomepageHeader() {
  return (
    <header className={styles.hero}>
      <div className={clsx('container', styles.heroInner)}>
        <Link className={styles.releasePill} to="/docs/release-notes/4.0.0">
          <span className={styles.releaseDot} aria-hidden="true" />
          Nauthilus 4.0 is here: see what's new
        </Link>
        <img className={styles.logo} src="/img/logo_nauthilus_light.png" alt="Nauthilus" width="600" height="544" />
        <Heading as="h1" className={styles.heroTitle}>
          One central <span className={styles.accent}>policy engine</span>
          <br />
          for authentication and authorization.
        </Heading>
        <p className={styles.heroLead}>
          Mail servers, web applications, identity flows and APIs no longer decide alone. Nauthilus collects the facts
          behind every request (identity, network, reputation, brute-force history, MFA state) and returns one
          consistent decision, with the obligations to enforce it.
        </p>
        <div className={styles.buttons}>
          <Link className={clsx('button button--lg', styles.primaryButton)} to="/docs/about/getting-started">
            Get started
          </Link>
          <Link className={clsx('button button--lg', styles.ghostButton)} to="#tour">
            ▶ Watch the 76-second tour
          </Link>
        </div>
      </div>
    </header>
  );
}

function TourSection() {
  return (
    <section id="tour" className={styles.tour}>
      <div className={clsx('container', styles.tourInner)}>
        <div className={styles.sectionIntro}>
          <p className={styles.eyebrow}>Nauthilus in 76 seconds</p>
          <Heading as="h2" className={styles.sectionTitle}>
            Who decides?
          </Heading>
          <p className={styles.sectionLead}>
            Today every service decides alone: different lockouts, different MFA rules, different blind spots. Here is
            what changes when one engine makes the call.
          </p>
        </div>
        <PromoVideo />
      </div>
    </section>
  );
}

function DecisionSection() {
  return (
    <section className={styles.decision}>
      <div className="container">
        <div className={styles.sectionIntro}>
          <p className={styles.eyebrow}>How it works</p>
          <Heading as="h2" className={styles.sectionTitle}>
            Facts in. <span className={styles.accent}>Decision out.</span>
          </Heading>
          <p className={styles.sectionLead}>
            Declarative policies evaluate the facts at each checkpoint of a request and answer with a clear verdict and
            the obligations that go with it. Try new rules in observe mode first, then enforce them once you trust them.
          </p>
        </div>
        <div className={styles.flow} aria-label="Facts flow into the policy engine, which returns a decision">
          <ul className={styles.facts}>
            {facts.map((fact) => (
              <li key={fact} className={styles.fact}>
                {fact}
              </li>
            ))}
          </ul>
          <div className={styles.flowArrow} aria-hidden="true" />
          <div className={styles.engine}>
            <img src="/img/logo_mark_light.png" alt="" className={styles.engineLogo} />
            <span>Policy engine</span>
          </div>
          <div className={styles.flowArrow} aria-hidden="true" />
          <ul className={styles.decisions}>
            {decisions.map(({verdict, tone, obligations}) => (
              <li key={verdict} className={clsx(styles.decisionCard, tone)}>
                <span className={styles.decisionLabel}>Decision</span>
                <span className={styles.verdict}>{verdict}</span>
                <span className={styles.obligations}>+ {obligations}</span>
              </li>
            ))}
          </ul>
        </div>
        <p className={styles.flowFootnote}>Same rules. Every service. Every time.</p>
        <div className={styles.centerLink}>
          <Link to="/docs/configuration/auth-policy">Read the policy configuration guide →</Link>
        </div>
      </div>
    </section>
  );
}

function EntryPointsSection() {
  return (
    <section className={styles.entryPoints}>
      <div className="container">
        <div className={styles.sectionIntro}>
          <p className={styles.eyebrow}>Integrations</p>
          <Heading as="h2" className={styles.sectionTitle}>
            One engine. <span className={styles.accent}>Every entry point.</span>
          </Heading>
        </div>
        <div className={styles.entryGrid}>
          {entryPoints.map(({title, tags, description, to}) => (
            <Link key={title} to={to} className={styles.entryCard}>
              <span className={styles.entryTags}>{tags}</span>
              <Heading as="h3" className={styles.entryTitle}>
                {title}
              </Heading>
              <p>{description}</p>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

function SupportSection() {
  return (
    <section className={styles.support}>
      <div className={clsx('container', styles.supportInner)}>
        <p className={styles.eyebrow}>Running it in production?</p>
        <Heading as="h2" className={styles.sectionTitle}>
          Enterprise support. <span className={styles.accent}>Directly from the maintainer.</span>
        </Heading>
        <ul className={styles.supportTopics}>
          <li>Architecture</li>
          <li>Integration</li>
          <li>Customization</li>
          <li>Troubleshooting</li>
        </ul>
        <div className={styles.buttons}>
          <a className={clsx('button button--lg', styles.primaryButton)} href="mailto:support@nauthilus.com">
            support@nauthilus.com
          </a>
          <Link className={clsx('button button--lg', styles.ghostButton)} href="https://github.com/croessner/nauthilus">
            Source code on GitHub
          </Link>
        </div>
        <p className={styles.supportNote}>
          Nauthilus is open source under the GPLv3, written in Go. You can also{' '}
          <Link href="https://github.com/sponsors/croessner">sponsor its development</Link>.
        </p>
      </div>
    </section>
  );
}

export default function Home() {
  return (
    <Layout
      title="Central policy engine for authentication and authorization"
      description="Nauthilus is an open source central policy engine for authentication and authorization: one consistent decision for mail, web SSO (OIDC, SAML 2.0), APIs and identity flows.">
      <HomepageHeader />
      <main>
        <TourSection />
        <DecisionSection />
        <EntryPointsSection />
        <HomepageFeatures />
        <SupportSection />
      </main>
    </Layout>
  );
}
