import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Nginx',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        The community HTTP server does not provide a free authentication service. The parameter mail::auth_http requires a server which handles the main authentication request. This does Nauthilus.
      </>
    ),
  },
  {
    title: 'Dovecot',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Nauthilus has great Dovecot support and can be integrated with the Lua backend.
      </>
    ),
  },
  {
    title: 'SSO',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        With the help of the open source OAuth2 OpenID connect server from Ory Hydra, Nauthilus can be used for their login, consent and logout flows.
      </>
    ),
  },
  {
    title: 'Security',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Nauthilus has great brute force detection logic. It can also deal with realtime blackhole lists and many more features.
      </>
    ),
  },
  {
    title: 'Lua support',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        Lua is included in all areas of the code. Starting with self written features to filter out requests before authentication starts. Continuing with full backend support and filters. Also post actions are available.
      </>
    ),
  },
  {
    title: 'Database support',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        There is currently support for OpenLDAP/AD, MySQL/MariaDB, Postgres and Lua.
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
        <div className="row">
          {FeatureList.map((props, idx) => (
            <FeatureNoSvg key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
