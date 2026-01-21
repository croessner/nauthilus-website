// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';
import { createRequire } from 'module';

// Determine latest product version including patch (e.g., 1.10.1)
const require = createRequire(import.meta.url);
const latestProductVersion =
  process.env.NAUTHILUS_LATEST_VERSION ||
  (() => {
    try {
      // optional JSON file maintained by CI
      // { "version": "1.10.1" }
      return require('./latest-version.json').version;
    } catch (_) {
      return undefined;
    }
  })() ||
  '1.12.0';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Nauthilus',
  tagline: 'Authentication and authorization server',
  favicon: 'img/favicon.ico',
  onBrokenAnchors: "ignore",

  // Set the production url of your site here
  url: 'https://nauthilus.org',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'croessner', // Usually your GitHub org/user name.
  projectName: 'nauthilus', // Usually your repo name.

  onBrokenLinks: 'throw',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/croessner/nauthilus-website/tree/main',
          // Treat 1.12 as the latest stable docs version; "current" is unreleased/next
          lastVersion: '1.12',
          versions: {
            current: {
              label: 'Next',
              banner: 'unreleased',
            },
            '1.12': {
              label: '1.12',
              banner: 'none',
            },
            '1.11': {
              label: '1.11',
              banner: 'none',
            },
            '1.10': {
              label: '1.10',
              banner: 'none',
            },
          },
        },
        blog: {
          showReadingTime: true,
          editUrl: 'https://github.com/croessner/nauthilus-website/tree/main',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: 'dark',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
      mermaid: {
        theme: { light: 'default', dark: 'dark' },
      },
      metadata: [
        { name: 'keywords', content: 'authentication, authorization' },
        { name: 'twitter:card', content: 'summary_large_image' },
        { property: 'og:title', content: 'Nauthilus - Authentication & Authorization Server' },
        { property: 'og:description', content: 'Nauthilus provides a powerful authentication and authorization server for modern applications.' },
        { property: 'og:image', content: 'https://nauthilus.org/img/logo_nauthilus.png' },
        { property: 'og:url', content: 'https://nauthilus.org' },
        { name: 'twitter:title', content: 'Nauthilus - Authentication & Authorization Server' },
        { name: 'twitter:description', content: 'Nauthilus provides a powerful authentication and authorization server for modern applications.' },
        { name: 'twitter:image', content: 'https://nauthilus.org/img/logo_nauthilus.png' },
      ],
      headTags: [
        // Declare a <link> preconnect tag
        {
          tagName: 'link',
          attributes: {
            rel: 'preconnect',
            href: 'https://nauthilus.org',
          },
        },
        // Declare some json-ld structured data
        {
          tagName: 'script',
          attributes: {
            type: 'application/ld+json',
          },
          innerHTML: JSON.stringify({
            '@context': 'https://schema.org/',
            '@type': 'Organization',
            name: 'Nauthilus',
            url: 'https://nauthilus.org/',
            logo: 'https://nauthilus.org/img/logo.png',
          }),
        },
      ],

      // Replace with your project's social card
      image: 'img/docusaurus-social-card.jpg',
      navbar: {
        title: 'Nauthilus',
        logo: {
          alt: 'Nauthilus Logo',
          src: 'img/logo.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'documentationSidebar',
            position: 'left',
            label: 'Documentation',
          },
          // Versions dropdown (docs versioning)
          {
            type: 'docsVersionDropdown',
            position: 'right',
            dropdownActiveClassDisabled: true
          },
          // Compact badge showing the latest product version incl. patch
          {
            label: `v${latestProductVersion}`,
            position: 'right',
            href: `https://github.com/croessner/nauthilus/releases/tag/v${latestProductVersion}`,
            className: 'navbar__item--version-badge',
          },
          {to: '/blog', label: 'Blog', position: 'left'},
          {
            href: 'https://github.com/croessner/nauthilus',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },

      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Documentation',
                to: '/docs/intro',
              },
            ],
          },
          {
            title: 'Legal information',
            items: [
              {
                label: 'Imprint',
                to: '/imprint',
              },
              {
                label: 'Impressum',
                to: '/de/impressum',
              },
              {
                label: 'Privacy policy',
                to: '/privacy-policy',
              },
              {
                label: 'Datenschutzerklärung',
                to: '/de/datenschutz',
              },
            ],
          },
          /*
          {
            title: 'Community',
            items: [
              {
                label: 'Stack Overflow',
                href: 'https://stackoverflow.com/questions/tagged/docusaurus',
              },
              {
                label: 'Discord',
                href: 'https://discordapp.com/invite/docusaurus',
              },
              {
                label: 'Twitter',
                href: 'https://twitter.com/docusaurus',
              },
            ],
          },
          */
          {
            title: 'More',
            items: [
              /*
              {
                label: 'Blog',
                to: '/blog',
              },
              */
              {
                label: 'GitHub',
                href: 'https://github.com/croessner/nauthilus',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Nauthilus, R.N.S.. Built with Docusaurus.`,
      },

      prism: {
        theme: prismThemes.vsLight,
        darkTheme: prismThemes.vsDark,
        additionalLanguages: ['lua', 'yaml'],
      },
    }),

  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },
  plugins: [],
  themes: [
    '@docusaurus/theme-mermaid',
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        language: ['en'],
        highlightSearchTermsOnTargetPage: true,
        indexBlog: false,
      },
    ],
  ],
};

export default config;
