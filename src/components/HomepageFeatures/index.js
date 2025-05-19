import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Multi-Protocol Authentication',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        Supports multiple protocols including HTTP/Nginx, Dovecot, Cyrus-SASL, and various mail protocols (IMAP, POP3, SMTP). Seamlessly integrates with web applications via OAuth2/OpenID Connect.
      </>
    ),
  },
  {
    title: 'Flexible Authentication Backends',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Choose from multiple backends including LDAP (OpenLDAP/Active Directory), Lua for custom logic, and Redis for high-performance caching. Easily extend with your own authentication providers.
      </>
    ),
  },
  {
    title: 'Advanced Security Features',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Comprehensive security with configurable brute force protection, realtime blackhole lists (RBL), network security controls, and domain validation to keep your authentication system secure.
      </>
    ),
  },
  {
    title: 'Single Sign-On (SSO)',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        Seamless integration with Keycloak via nauthilus-keycloak for OAuth2/OpenID Connect support. Implement role-based access control and modern authentication flows for your applications.
      </>
    ),
  },
  {
    title: 'Powerful Lua Scripting',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        Extensive Lua API for customization at every stage of the authentication process. Create filters, integrate with third-party services, implement custom logic, and extend functionality with ease.
      </>
    ),
  },
  {
    title: 'High Performance & Reliability',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Optimized for performance with Redis integration, connection pooling, efficient caching, and support for modern protocols like HTTP/2 and HTTP/3. Designed for high-availability deployments.
      </>
    ),
  },
  {
    title: 'Comprehensive Monitoring',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        Built-in Prometheus metrics, Grafana dashboard templates, and backend server monitoring. Get detailed insights into your authentication system's performance and health.
      </>
    ),
  },
  {
    title: 'Enterprise-Ready',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
        <>
          Docker and Kubernetes support, flexible configuration options, and commercial support available. For enterprise inquiries, contact us at: <a href="mailto:support@nauthilus.com">support@nauthilus.com</a>.
        </>
    ),
  },
];

function Feature({Svg, title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

function FeatureNoSvg({title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="text--center margin-bottom--lg">
          <Heading as="h2">Key Features</Heading>
          <p>Discover what makes Nauthilus the ideal authentication and authorization solution</p>
        </div>
        <div className="row">
          {FeatureList.map((props, idx) => (
            <FeatureNoSvg key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
