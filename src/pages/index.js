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
                    className="logo-nauthilus logo-effect"
                    src="/img/logo_nauthilus.png"
                    alt="Nauthilus Logo"
                />
                <p className="hero__subtitle">Authentication & Authorization Server</p>
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
