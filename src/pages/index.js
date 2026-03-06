import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import styles from './index.module.css';

function HomepageHeader() {
    return (
        <header className={clsx('hero hero--primary', styles.heroBanner)} style={{ textAlign: 'center' }}>
            <div className="container">
                <img
                    className="logo-nauthilus logo-effect"
                    src="/img/logo_nauthilus.png"
                    alt="Nauthilus Logo"
                />
                <p className="hero__subtitle">Authentication & Authorization Server</p>
                <p className={styles.idpHighlight}>
                    Native Identity Provider: OIDC + SAML2 with integrated consent and MFA.
                </p>
                <div className={styles.buttons}>
                    <Link className="button button--secondary button--lg margin-right--sm" to="/docs/next/configuration/idp/oidc">
                        Explore Native IdP
                    </Link>
                    <Link className="button button--outline button--lg" to="/docs/rest-api">
                        View IdP Endpoints
                    </Link>
                </div>
            </div>
        </header>
    );
}

export default function Home() {
    const {siteConfig} = useDocusaurusContext();
    return (
        <Layout
            title={`${siteConfig.title}`}
            description="Authentication and authorization Server">
            <HomepageHeader />

            <main>
                <HomepageFeatures />
            </main>
        </Layout>
    );
}
