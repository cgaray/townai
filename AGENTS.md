# AGENTS.md

This file contains guidelines and commands for agentic coding agents working in this Rails + TypeScript codebase.

## Project Structure

This is a Rails 8.1 application with TypeScript/Bun frontend components:
- **Backend**: Ruby on Rails 8.1 with SQLite, Active Storage, Solid Queue/Cable/Cache
- **Frontend**: TypeScript with Bun, Tailwind CSS, DaisyUI, Stimulus
- **Deployment**: Kamal (Docker-based)

## Essential Commands

### Ruby/Rails Commands
```bash
# Setup the entire application
bin/setup

# Run Rails server
bin/rails s

# Run Rails console
bin/rails c

# Database operations
bin/rails db:migrate
bin/rails db:seed
bin/rails db:reset

# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/document_test.rb

# Run single test method
bin/rails test test/models/document_test.rb -n test_should_create_document

# Search index operations
bin/rails search:rebuild      # Rebuild entire search index
bin/rails search:stats        # Show index statistics
```

### Code Quality & Security
```bash
# Ruby linting/style checking
bin/rubocop

# Auto-fix RuboCop issues
bin/rubocop -a

# Security audit for gems
bin/bundler-audit

# Security vulnerability scanning
bin/brakeman

# Importmap vulnerability audit
bin/importmap audit
```

### TypeScript/Bun Commands
```bash
# Install dependencies
bun install

# Run TypeScript file
bun index.ts

# Run tests (if any exist)
bun test

# Build frontend assets
bun build
```

### Full CI Pipeline
```bash
# Run complete CI suite locally
bin/ci
```

## Code Style Guidelines

### Ruby/Rails Style
- Follow RuboCop Rails Omakase configuration (`.rubocop.yml`)
- Use Rails 8.1 conventions and patterns
- Prefer `enum` over string constants for model statuses
- Use `has_one_attached`/`has_many_attached` for Active Storage
- Follow RESTful controller patterns
- Use `stale_when_importmap_changes` in controllers with importmap

### Model Conventions
```ruby
class Document < ApplicationRecord
  has_one_attached :pdf
  
  enum :status, [:pending, :extracting_text, :extracting_metadata, :complete, :failed]
  
  # Use descriptive method names
  def metadata_field(field)
    return nil unless extracted_metadata.present?
    JSON.parse(extracted_metadata)[field] rescue nil
  end
end
```

### Controller Conventions
```ruby
class DocumentsController < ApplicationController
  def index
    @status_counts = Document.group(:status).count
    @documents = Document.order(created_at: :desc).limit(100)
  end
  
  def show
    @document = Document.find(params[:id])
  end
end
```

### TypeScript Style
- Use strict TypeScript configuration (`tsconfig.json`)
- Prefer ESNext syntax and features
- Use `bun:sqlite` instead of `better-sqlite3`
- Use `Bun.serve()` instead of Express
- Import CSS files directly in TypeScript
- Use React with JSX transform

### Import Conventions
```typescript
// Node.js built-ins
import { serve } from "bun";

// Local files (use relative paths)
import { helper } from "./helper";
import "./styles.css";

// React
import React from "react";
import { createRoot } from "react-dom/client";
```

### Frontend Architecture
- Use HTML imports with `Bun.serve()` routing
- Import `.tsx`, `.jsx`, `.css` files directly in HTML
- Use Stimulus for JavaScript controllers
- Tailwind CSS with DaisyUI for styling
- Hot Module Replacement with `bun --hot`

### Error Handling
- Use `rescue nil` for safe JSON parsing in models
- Implement proper error handling in controllers
- Use Rails exception handling patterns
- Return meaningful error responses

### Testing Patterns
- Use Rails built-in testing framework
- Place tests in `test/` directory mirroring `app/` structure
- Use fixtures for test data
- Test models, controllers, jobs, and system integration
- Run tests in parallel with `parallelize(workers: :number_of_processors)`

### Security Guidelines
- Always run `bin/bundler-audit` and `bin/brakeman` before commits
- Use Rails security features (CSRF, CSP, etc.)
- Validate and sanitize user inputs
- Use parameter filtering for sensitive data
- Keep dependencies updated

### Database Patterns
- Use Rails migrations with descriptive names
- Follow Active Record conventions
- Use Solid Queue for background jobs
- Use Solid Cache for caching
- Use Solid Cable for Action Cable
- Use SQLite FTS5 for full-text search (see `SearchEntry` model)

### Full-Text Search

The application uses SQLite FTS5 for full-text search via `SearchEntry` model:

```ruby
# Search across all indexed content
SearchEntry.search("budget", types: ["document", "topic"], limit: 20)

# Get counts by entity type
SearchEntry.counts_by_type("budget")

# Reindex content (runs via background job)
SearchIndexer.index_document(document)
SearchIndexer.index_person(person)
SearchIndexer.index_governing_body(governing_body)

# Rebuild entire index
bin/rails search:rebuild
```

**Indexed entities:** Documents (with topics indexed separately), People, Governing Bodies

**Note:** FTS5 is SQLite-specific. The search feature uses SQL schema format (`db/structure.sql`) to properly handle the virtual table.

### Asset Management
- Use Propshaft for asset pipeline
- Use Importmap for JavaScript dependencies
- Use Tailwind CSS for styling
- Use Active Storage for file uploads

### UI Design System

The application uses a custom design system built on DaisyUI with a bold, vibrant civic theme.

#### Color Palette
- **Primary**: Royal blue (`#2563EB`) - CTAs, links, primary actions
- **Secondary**: Civic red (`#DC2626`) - important accents
- **Accent**: Emerald (`#059669`) - success states
- **Document Types**: Agenda (blue gradient), Minutes (purple gradient)

#### Icons Helper (`app/helpers/icons_helper.rb`)
Use SVG icons from Heroicons instead of emoji:

```erb
<%# Basic icon %>
<%= icon("document", size: "w-5 h-5") %>

<%# Icon with custom class %>
<%= icon("arrow-path", size: "w-4 h-4", class: "text-primary") %>

<%# Icon in gradient circle %>
<%= icon_in_circle("building-library", type: :brand, size: :lg) %>

<%# Document type icon with appropriate gradient %>
<%= document_type_icon("agenda", size: :md) %>
```

Available icons: `document`, `agenda`, `minutes`, `calendar`, `clock`, `users`, `check-circle`, `x-circle`, `arrow-path`, `building-library`, `chevron-left`, `folder-open`, `bars-3`, `list-bullet`, `file`, `currency-dollar`, `exclamation-triangle`, `identification`, `magnifying-glass`

#### Documents Helper (`app/helpers/documents_helper.rb`)
```erb
<%# Status badge with icon (uses DaisyUI loading spinner for processing states) %>
<%= status_badge(document.status) %>

<%# Document type icon in gradient circle %>
<%= document_type_icon(doc.metadata_field("document_type"), size: :lg) %>

<%# Document type badge for timelines %>
<%= document_type_badge(doc_type) %>

<%# Border class for document type %>
<div class="card <%= document_type_border_class(doc_type) %>">

<%# Action badge with icon %>
<%= action_badge("approved") %>

<%# Section header with icon and optional count %>
<%= section_header("Attendees", icon_name: "users", count: 5) %>

<%# DaisyUI avatar with initials (uses avatar-placeholder component) %>
<%= avatar(person.name, size: :lg) %>
<%# Sizes: :sm (32px), :md (40px), :lg (48px), :xl (64px) %>
```

#### Shared View Partials (`app/views/shared/`)
```erb
<%# Page header with gradient title %>
<%= render "shared/page_header", title: "Documents", subtitle: "Town meeting agendas", badge: badge_content %>

<%# Back navigation link %>
<%= render "shared/back_link", path: documents_path, text: "Back to Documents" %>

<%# Empty state card %>
<%= render "shared/empty_state", icon_name: "folder-open", title: "No documents", description: "..." %>

<%# Pagination %>
<%= render "shared/pagination", pagy: @pagy, url_builder: ->(page) { pagy_url_for(@pagy, page) } %>

<%# Collapsible source text %>
<%= render "shared/source_text_details", source_text: text, label: "Show source" %>

<%# Stat card for dashboards %>
<%= render "shared/stat_card", icon_name: "calendar", title: "This Month", value: "$1.23", subtitle: "..." %>

<%# Search modal (included in application layout) %>
<%# Triggered by Cmd/Ctrl+K keyboard shortcut %>
```

#### CSS Utility Classes (`app/assets/tailwind/application.css`)
```css
/* Card hover animation */
.card-hover { /* scale(1.02) + shadow on hover */ }

/* Gradient text */
.text-gradient-primary { /* Blue gradient text */ }

/* Icon circles with gradients */
.icon-circle.icon-circle-agenda { /* Blue gradient */ }
.icon-circle.icon-circle-minutes { /* Purple gradient */ }
.icon-circle.icon-circle-brand { /* Primary gradient */ }

/* Document type borders */
.border-t-agenda { /* 4px blue top border */ }
.border-t-minutes { /* 4px purple top border */ }
.border-t-brand { /* 4px primary blue top border */ }

/* Animations */
.animate-pulse-subtle { /* Subtle opacity pulse */ }
.animate-slide-up { /* Fade in from below */ }

/* Numbered list circles */
.number-circle { /* Circular number indicator */ }
```

**Note:** For loading spinners, use DaisyUI's built-in `loading` component:
```erb
<span class="loading loading-spinner loading-sm"></span>
```

**Note:** For avatars, use the `avatar` helper which renders DaisyUI's `avatar-placeholder` component.

### Naming Conventions
- Use snake_case for Ruby files and methods
- Use PascalCase for classes and modules
- Use camelCase for JavaScript/TypeScript
- Use kebab-case for file names in views
- Use descriptive variable and method names

## Development Workflow

1. Run `bin/setup` for initial setup
2. Use `bin/rails s` for development server
3. Run `bin/rubocop -a` before committing
4. Run `bin/ci` to verify everything works
5. Use `bin/rails test` for running tests
6. Use `bin/rails c` for debugging in console

## Important Notes

- This application uses Bun instead of Node.js for frontend tooling
- Rails 8.1 uses Solid suite for queueing, caching, and cables
- The application is configured for Kamal deployment
- Always use the provided bin scripts instead of direct gem commands
- Follow Rails conventions and patterns throughout the codebase