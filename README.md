# Hikari Documentation

This directory contains the documentation website for Hikari, built with [Docusaurus](https://docusaurus.io/).

## 🚀 Quick Start

### Prerequisites

- Node.js version 18.0 or above

### Development

```bash
cd docs
npm install
npm start
```

This starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Build

```bash
npm run build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

### Deployment

The documentation is automatically deployed to GitHub Pages when changes are pushed to the main branch.

## 📁 Structure

```
docs/
├── blog/                 # Blog posts
├── docs/                 # Documentation pages
│   ├── intro.md         # Getting started
│   ├── routing.md       # Routing and middleware
│   ├── context.md       # Context management
│   ├── api.md           # API reference
│   └── examples.md      # Examples
├── src/                  # React components and pages
├── static/              # Static assets
├── i18n/                # Internationalization
│   └── pt-BR/           # Portuguese translations
├── docusaurus.config.ts # Site configuration
└── sidebars.ts          # Sidebar configuration
```

## 🌐 Internationalization

The documentation supports multiple languages:

- **English** (default)
- **Português (Brasil)**

To add a new language or update translations, modify the files in the `i18n/` directory.

### Build for Specific Locale

```bash
# Build only English
npm run build

# Build only Portuguese
npm run build -- --locale pt-BR

# Build all locales
npm run build
```

### Development with Locale

```bash
# Start with Portuguese locale
npm run start -- --locale pt-BR
```

## 📝 Contributing

1. **Documentation**: Edit markdown files in the `docs/` directory
2. **Blog posts**: Add new posts to the `blog/` directory
3. **Translations**: Update files in `i18n/pt-BR/docusaurus-plugin-content-docs/current/`
4. **Components**: Modify React components in `src/`

### Writing Guidelines

- Use clear, concise language
- Include code examples for all features
- Test all code examples before publishing
- Follow the existing structure and style
- Update both English and Portuguese versions when possible

## 🔧 Configuration

The main configuration is in `docusaurus.config.ts`. Key settings:

- **Site metadata**: title, tagline, URL
- **Internationalization**: supported locales
- **Theme configuration**: navbar, footer, colors
- **Plugin settings**: docs, blog, search

## 📦 Available Scripts

- `npm start` - Start development server
- `npm run build` - Build for production
- `npm run serve` - Serve built site locally
- `npm run clear` - Clear Docusaurus cache
- `npm run write-translations` - Extract translatable strings
- `npm run write-heading-ids` - Generate heading IDs

## 🚀 Deployment

The site is automatically deployed to GitHub Pages via GitHub Actions when:

1. Changes are pushed to the `main` branch
2. Files in the `docs/` directory are modified
3. The workflow file `.github/workflows/docs.yml` is updated

The deployment URL: https://gabehamasaki.github.io/hikari-go/

## 📋 TODO

- [ ] Add more comprehensive examples
- [ ] Create video tutorials
- [ ] Add API playground/interactive examples
- [ ] Improve search functionality
- [ ] Add more translations (Spanish, French, etc.)
- [ ] Create migration guides
- [ ] Add community section
