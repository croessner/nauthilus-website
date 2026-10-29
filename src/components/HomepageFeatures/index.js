import clsx from 'clsx';
import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Built for hostile traffic',
    to: '/docs/brute-force-protection',
    description: (
      <>
        Brute-force protection, realtime blocklists, reputation and password-leak checks feed the decision as facts,
        so attacks are stopped consistently on every protocol instead of service by service.
      </>
    ),
  },
  {
    title: 'Policies you can trust',
    to: '/docs/configuration/auth-policy',
    description: (
      <>
        Declarative rules per checkpoint, explicit allow, deny and tempfail outcomes, and obligations such as step-up
        MFA. Observe mode shows what a rule would do before it is allowed to enforce.
      </>
    ),
  },
  {
    title: 'Identity and MFA built in',
    to: '/docs/configuration/idp/mfa-assurance',
    description: (
      <>
        A native OIDC and SAML 2.0 identity provider with consent, dynamic client registration, TOTP, WebAuthn and
        recovery codes, all governed by the same policy engine.
      </>
    ),
  },
  {
    title: 'Facts from your infrastructure',
    to: '/docs/configuration/database-backends',
    description: (
      <>
        LDAP and Active Directory, Lua and remote backends supply identities and attributes. Redis-backed caches for
        positive password checks and identity lookups keep the directory load low.
      </>
    ),
  },
  {
    title: 'Extend it your way',
    to: '/docs/configuration/native-go-plugins',
    description: (
      <>
        Native Go plugins and an extensive Lua API add your own facts, checks and actions without forking the server.
        Plugin configuration reloads on SIGHUP.
      </>
    ),
  },
  {
    title: 'Observable and ready to scale',
    to: '/docs/configuration/metrics',
    description: (
      <>
        Prometheus metrics, OpenTelemetry tracing and Grafana dashboards show every decision. Redis, Sentinel and
        Cluster support plus Docker and Kubernetes images make it run anywhere.
      </>
    ),
  },
];

function Feature({title, to, description}) {
  return (
    <div className={clsx('col col--4', styles.col)}>
      <Link to={to} className={styles.card}>
        <Heading as="h3" className={styles.title}>
          {title}
        </Heading>
        <p className={styles.text}>{description}</p>
        <span className={styles.more}>Learn more →</span>
      </Link>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className={styles.intro}>
          <p className={styles.eyebrow}>Why Nauthilus</p>
          <Heading as="h2" className={styles.heading}>
            Observable. Safe to change live. <span className={styles.accent}>Open source.</span>
          </Heading>
        </div>
        <div className="row">
          {FeatureList.map((props) => (
            <Feature key={props.title} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
