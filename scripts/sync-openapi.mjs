#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import yaml from 'js-yaml';

const args = new Set(process.argv.slice(2));
const checkOnly = args.has('--check');
const cleanGenerated = args.has('--clean-generated');
const repoRoot = process.cwd();
const sourceDir = path.resolve(
  repoRoot,
  process.env.NAUTHILUS_OPENAPI_SOURCE_DIR || '../nauthilus/server/openapi',
);
const staticDir = path.join(repoRoot, 'static', 'openapi');
const docsDir = path.join(repoRoot, 'docs', 'api-reference');
const methods = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace'];

const specs = [
  {
    key: 'management',
    sourceFile: 'openapi.yaml',
    yamlFile: 'management.yaml',
    jsonFile: 'management.json',
    categoryLabel: 'Management API',
    description: 'Protected management and backchannel endpoints.',
    sidebarPosition: 1,
  },
  {
    key: 'idp',
    sourceFile: 'idp.yaml',
    yamlFile: 'idp.yaml',
    jsonFile: 'idp.json',
    categoryLabel: 'IdP API',
    description: 'Public IdP, OIDC, SAML, and browser flow endpoints.',
    sidebarPosition: 2,
  },
];

function main() {
  if (cleanGenerated) {
    cleanGeneratedFiles();

    return;
  }

  const expectedFiles = new Map();
  const sourceAvailable = fs.existsSync(sourceDir);

  if (!sourceAvailable) {
    console.warn(`OpenAPI source directory not found, using committed static specs: ${sourceDir}`);
  }

  const renderedSpecs = specs.map((spec) => renderSpecFiles(spec, sourceAvailable));

  for (const rendered of renderedSpecs) {
    expectedFiles.set(path.join(staticDir, rendered.spec.yamlFile), rendered.yamlText);
    expectedFiles.set(path.join(staticDir, rendered.spec.jsonFile), rendered.jsonText);
    expectedFiles.set(path.join(docsDir, rendered.spec.key, '_category_.json'), renderSpecCategory(rendered));
  }

  expectedFiles.set(path.join(docsDir, '_category_.json'), renderCategory());
  expectedFiles.set(path.join(docsDir, 'index.md'), renderIndex(renderedSpecs));

  const staleFiles = [
    path.join(docsDir, 'management.md'),
    path.join(docsDir, 'idp.md'),
  ];

  if (checkOnly) {
    checkFiles(expectedFiles, staleFiles);

    return;
  }

  writeFiles(expectedFiles, staleFiles);
}

function cleanGeneratedFiles() {
  const generatedFiles = listFiles(docsDir)
    .filter((filePath) => filePath.endsWith('.mdx'));

  for (const filePath of generatedFiles) {
    const original = fs.readFileSync(filePath, 'utf8');
    const cleaned = ensureTrailingNewline(original.replace(/[ \t]+$/gm, '').replace(/\n+$/g, ''));

    if (cleaned !== original) {
      fs.writeFileSync(filePath, cleaned);
    }
  }

  console.log(`Cleaned ${generatedFiles.length} generated OpenAPI MDX files.`);
}

function renderSpecFiles(spec, sourceAvailable) {
  const sourcePath = path.join(sourceDir, spec.sourceFile);
  const committedPath = path.join(staticDir, spec.yamlFile);
  const yamlText = ensureTrailingNewline(readSpecSource(sourceAvailable ? sourcePath : committedPath));
  const document = yaml.load(yamlText);
  const jsonText = `${JSON.stringify(document, null, 2)}\n`;
  const infoId = slugifyInfoTitle(document.info?.title || spec.categoryLabel);
  const operationCount = countOperations(document);
  const schemaCount = Object.keys(document.components?.schemas || {}).length;

  return { spec, yamlText, jsonText, document, infoId, operationCount, schemaCount };
}

function readSpecSource(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`OpenAPI spec not found: ${filePath}`);
  }

  return fs.readFileSync(filePath, 'utf8');
}

function writeFiles(files, staleFiles) {
  for (const [filePath, content] of files) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
  }

  for (const filePath of staleFiles) {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  }

  console.log(`Synced ${files.size} OpenAPI support files.`);
}

function checkFiles(files, staleFiles) {
  const staleMessages = [];

  for (const [filePath, expected] of files) {
    if (!fs.existsSync(filePath)) {
      staleMessages.push(`${relative(filePath)} is missing`);

      continue;
    }

    const actual = fs.readFileSync(filePath, 'utf8');
    if (actual !== expected) {
      staleMessages.push(`${relative(filePath)} is out of sync`);
    }
  }

  for (const filePath of staleFiles) {
    if (fs.existsSync(filePath)) {
      staleMessages.push(`${relative(filePath)} should be removed`);
    }
  }

  if (staleMessages.length > 0) {
    console.error('OpenAPI support files are not up to date:');
    for (const staleMessage of staleMessages) {
      console.error(`- ${staleMessage}`);
    }
    console.error('Run: npm run openapi:sync');

    process.exitCode = 1;

    return;
  }

  console.log('OpenAPI support files are in sync.');
}

function renderCategory() {
  return `${JSON.stringify(
    {
      label: 'API Reference',
      position: 11,
      link: {
        type: 'doc',
        id: 'api-reference/index',
      },
    },
    null,
    2,
  )}\n`;
}

function renderSpecCategory({ spec, infoId }) {
  return `${JSON.stringify(
    {
      label: spec.categoryLabel,
      position: spec.sidebarPosition,
      link: {
        type: 'doc',
        id: `api-reference/${spec.key}/${infoId}`,
      },
    },
    null,
    2,
  )}\n`;
}

function renderIndex(renderedSpecs) {
  const cards = renderedSpecs
    .map(({ spec, document, infoId, operationCount, schemaCount }) => {
      const title = document.info?.title || spec.categoryLabel;

      return `| [${spec.categoryLabel}](./${spec.key}/${infoId}) | ${escapeTable(title)} | ${operationCount} | ${schemaCount} | [YAML](/openapi/${spec.yamlFile}) · [JSON](/openapi/${spec.jsonFile}) |`;
    })
    .join('\n');

  return `---
title: API Reference
description: Generated OpenAPI references for Nauthilus HTTP APIs
keywords: [OpenAPI, REST API, API Reference, Nauthilus]
sidebar_position: 11
---

# API Reference

This section is generated from the OpenAPI contracts maintained in the Nauthilus server repository. The regular REST API documentation remains the narrative guide; these pages provide the endpoint explorer, request and response schemas, and downloadable raw contracts.

| Reference | Contract | Operations | Schemas | Raw Spec |
| --- | --- | ---: | ---: | --- |
${cards}

## Workflow

- Update the canonical specs in the server repository.
- Run \`npm run openapi:generate\` in this repository to refresh static specs and generated API docs.
- Run \`npm run build\` to verify the complete Docusaurus site.
`;
}

function countOperations(document) {
  let count = 0;

  for (const pathItem of Object.values(document.paths || {})) {
    for (const method of methods) {
      if (pathItem?.[method]) {
        count += 1;
      }
    }
  }

  return count;
}

function listFiles(directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }

  return fs.readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => {
      const entryPath = path.join(directory, entry.name);

      if (entry.isDirectory()) {
        return listFiles(entryPath);
      }

      return [entryPath];
    });
}

function slugifyInfoTitle(value) {
  return String(value)
    .replace(' ', '-')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function escapeTable(value) {
  return String(value || '').replaceAll('|', '\\|').replaceAll('\n', ' ');
}

function ensureTrailingNewline(value) {
  return value.endsWith('\n') ? value : `${value}\n`;
}

function relative(filePath) {
  return path.relative(repoRoot, filePath);
}

main();
