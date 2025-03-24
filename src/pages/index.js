import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';

import Heading from '@theme/Heading';
import styles from './index.module.css';

function HomepageHeader() {
    return (
        <header className={clsx('hero hero--primary', styles.heroBanner)} style={{ textAlign: 'center' }}>
            <div className="container">
                <img
                    src="/img/logo_nauthilus.png"  // Pfad zum Bild
                    alt="Nauthilus Logo"
                    style={{ width: '500px', height: 'auto' }}
                />
                <p className="hero__subtitle">Authentication and authorization Server</p>
                <div className={styles.buttons}>
                    <Link
                        className="button button--secondary button--lg"
                        to="/docs/intro">
                        Nauthilus documentation
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
            title={`Hello from ${siteConfig.title}`}
            description="Authentication and authorization Server">
            <HomepageHeader />

            <main>
                <HomepageFeatures />
            </main>
        </Layout>
    );
}
