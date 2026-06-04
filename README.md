# Lead Routing Delivery

This Rails app implements a CRM-style lead routing workflow. It receives inbound leads, validates them, checks DNC status, qualifies them, routes them to recipients, tracks delivery attempts, receives postbacks, and records conversions.

The goal is to make the lead lifecycle easy to review from the admin UI, not just from logs or test output.

---

## Quick Start: Run and Review

### 1. Install dependencies

```bash
bundle config set --local path "vendor/bundle"
bundle install
npm install
```

### 2. Set up the database

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

The seed step creates the admin user and the sample recipients.

### 3. Build CSS assets

```bash
npm run build:css
```

### 4. Start the Rails app

```bash
bin/rails server
```

Open the admin CRM:

```text
http://localhost:3000/admin
```

Sign in with:

```text
Email: admin@example.com
Password: password
```

### 5. Start the mock recipient server

In a second terminal:

```bash
CALLBACK_URL=http://localhost:3000/postbacks/recipients ruby mock_recipients/server.rb
```

The mock server supports DNC checks and the Apex, Beacon, and Citadel recipient endpoints.

### 6. Run the workflow

```bash
bin/rails leads:ingest FILE=data/inbound_leads.json
bin/rails leads:scrub_dnc
bin/rails leads:qualify
bin/rails leads:route
bin/rails leads:dispatch
```

After running these commands, review the results here:

```text
/admin/dashboard
/admin/leads
/admin/leads/:id
```

### 7. Run the test suite

```bash
bundle exec rspec
```

Final verified result:

```text
172 examples, 0 failures
```

---

## What the App Does

The workflow follows this path:

```text
Inbound lead data
  → validation
  → DNC suppression
  → qualification
  → routing
  → recipient delivery
  → postback handling
  → conversion tracking
  → admin review
```

Implemented functionality includes:

- Importing leads from `data/inbound_leads.json`
- Normalizing lead fields such as phone, email, dates, and state
- Storing invalid leads with clear validation errors
- Skipping duplicate leads by `source_claim_id`
- Running DNC checks through the mock service
- Qualifying leads based on prequalification fields
- Routing qualified leads to Apex, Beacon, and Citadel
- Tracking delivery attempts and recipient responses
- Handling retryable and permanent delivery failures
- Receiving signed recipient postbacks
- Recording conversions without creating duplicates
- Providing an ActiveAdmin interface for review and troubleshooting

---

## Admin CRM

The admin UI is the main place to review the workflow.

Useful pages:

```text
/admin
/admin/leads
/admin/leads/:id
```

The dashboard shows:

- Lead lifecycle summary
- Delivery status summary
- Recent failed dispatch attempts
- Recent conversions and postbacks
- Recent leads

The lead detail page shows:

- Lead summary
- Contact and incident information
- Validation and qualification results
- Recipient deliveries
- Dispatch attempts
- Conversions and postbacks
- Lifecycle timeline
- Raw payload

---

## Sample Data Result

Running the import task against the provided sample file should produce:

```text
total=25
created=24
valid=20
invalid=4
duplicates=1
failed=0
```

---

## Recipient Integrations

The app includes three recipient integrations.

### Apex

```text
POST /apex/v2/leads
JSON payload
X-Api-Key authentication
```

### Beacon

```text
POST /beacon/api/addLead
Form-encoded payload
API key submitted in the form body
```

Beacon can return HTTP 200 for both accepted and rejected leads, so the response body is checked before deciding the delivery result.

### Citadel

```text
POST /citadel/intake
JSON payload
Bearer token authentication
```

Citadel handles duplicate and rate-limit responses separately.

---

## Postbacks

Recipient postbacks are received at:

```text
POST /postbacks/recipients
```

Required fields:

```text
recipient
source_claim_id
external_id
disposition
occurred_at
signature
```

Supported dispositions:

```text
signed
rejected
not_qualified
```

Postbacks are signed using the shared secret configured for the app. Repeated postbacks do not create duplicate conversion records.

---

## Tech Stack

- Ruby 3.2.3
- Rails 8.1.3
- PostgreSQL
- ActiveAdmin
- Devise
- RSpec
- WebMock
- Net::HTTP
- Tailwind CSS / cssbundling-rails

---

## Configuration

Runtime configuration is stored in:

```text
config/assessment.yml
```

Local example values are provided in:

```text
.env.example
```

Important values include:

```text
MOCK_RECIPIENTS_BASE_URL
RECIPIENT_CALLBACK_URL
APEX_API_KEY
BEACON_API_KEY
CITADEL_BEARER_TOKEN
POSTBACK_SHARED_SECRET
DISPATCH_MAX_ATTEMPTS
```

---

## Design Notes

A few choices were made to keep the workflow reviewable and easy to extend:

- Lead decisions are recorded as lifecycle events.
- Recipient configuration is stored in the database instead of being hard-coded.
- Apex, Beacon, and Citadel each have their own client class.
- Dispatch records redacted request and response details.
- Imports and postbacks are idempotent.
- Routing and dispatch are separated so each step can be tested independently.

More detailed architecture notes are available in:

```text
docs/ARCHITECTURE.md
```

The original assignment materials are preserved in:

```text
docs/reference/ASSIGNMENT_README.md
```