# AegisMind — AI-Powered Emergency SOS Triage

AegisMind is a hackathon project that turns unstructured emergency reports into
prioritized incidents for a dispatcher dashboard. Citizens can submit an SOS,
receive immediate safety guidance and a short display reference, then track the
incident as responders dispatch and resolve it.

> **Safety notice:** This is a demonstration project, not a replacement for
> local emergency services. In a real emergency, contact your local emergency
> number immediately.

## Features

- SOS submission with optional GPS or manually entered location
- AI-assisted triage with rules-based fallback when the model is unavailable
- Category, urgency, resource, safety-advice, and summary extraction
- Nearby-report clustering to avoid duplicate dispatcher incidents
- Public status tracking by full incident ID or short display reference
- Dispatcher queues for open, dispatched, and resolved incidents
- Estimated arrival time (ETA) for dispatched help
- Live five-second polling for dashboard and tracker updates
- Frosted-glass responsive visual system for the citizen and dispatcher views

## Architecture

```text
Flutter web app
  ├─ Citizen SOS and status tracker
  └─ Dispatcher dashboard
           │ HTTPS
           ▼
Amazon API Gateway (/sos)
           │
           ▼
AWS Lambda triage engine ──► Gemini API
           │
           ▼
Amazon DynamoDB incident table
```

AWS CDK provisions the Lambda function, API Gateway, DynamoDB table, and an S3
static website deployment. The Flutter web build is uploaded by CDK during
deployment.

## Repository layout

```text
.
├── aegismind_frontend/       # Flutter UI (web, Android, iOS, desktop)
│   └── lib/
├── aegismind-backend/        # AWS CDK stack and Lambda source
│   ├── lambda/triage-engine/ # Node.js Lambda handler, rules, clustering, tests
│   └── lib/                  # CDK infrastructure definition
├── .env.example              # Safe root configuration template
└── readme.md
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Chrome or a
  supported device target
- Node.js 20 or later and npm
- AWS CLI configured for the AWS account used for deployment
- AWS CDK CLI access (`npx cdk` is included through backend dependencies)
- A Gemini API key and an available Gemini model

## Configure secrets safely

No credentials are committed to this repository.

1. Copy `aegismind-backend/.env.example` to `aegismind-backend/.env`.
2. Replace the placeholder values with your real Gemini key and model name.
3. Keep `.env` local. It is intentionally ignored by Git.

PowerShell:

```powershell
Copy-Item aegismind-backend\.env.example aegismind-backend\.env
```

For a named AWS profile, set it in the terminal before deployment:

```powershell
$env:AWS_PROFILE = "your-aws-profile"
aws sts get-caller-identity
```

## Run the Flutter app locally

The checked-in API configuration targets the deployed API by default. You can
override it with `API_BASE_URL` for another environment.

```powershell
cd aegismind_frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/prod/sos
```

Useful checks:

```powershell
flutter analyze
flutter test
```

## Test the backend

```powershell
cd aegismind-backend
npm ci
npm run test:lambda
npm test
```

The Lambda tests cover triage parsing, merge logic, and public status-ID
lookups, including uppercase short references and paginated DynamoDB scans.

## Deploy to AWS

Build the web app before CDK deployment; CDK uploads
`aegismind_frontend/build/web` to the website bucket.

```powershell
cd aegismind_frontend
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/prod/sos
```

Then deploy the infrastructure and web files:

```powershell
cd ..\aegismind-backend
npm ci
npx cdk bootstrap  # Required once per AWS account and region
npx cdk diff
npx cdk deploy
```

After deployment, CDK prints the website URL. Open it and hard-refresh the
browser (`Ctrl+F5`) to ensure the latest web assets are used.

## API overview

| Method | Route | Purpose |
| --- | --- | --- |
| `POST` | `/sos` | Submit and triage an SOS report |
| `GET` | `/sos` | List incidents for the dispatcher dashboard |
| `GET` | `/sos/{incidentIdOrReference}` | Fetch public status details |
| `PATCH` | `/sos/{incidentId}` | Update incident status and optional ETA |

The tracker accepts either a full stored incident ID or the eight-character
reference shown to citizens. Input is trimmed and normalized before lookup.

## Privacy and security notes

- Do not commit `.env`, AWS credentials, signing certificates, private keys,
  generated builds, archives, or CDK staging output.
- The dispatcher list currently contains sensitive incident details. Before a
  production launch, protect it with proper authentication and authorization.
- Rotate any API key that may have been committed or otherwise exposed.
- The default API URL is public configuration, not a secret; it can be safely
  supplied through `--dart-define=API_BASE_URL`.

## Hackathon submission checklist

- [ ] Confirm `.env` is absent from `git status`
- [ ] Run `npm run test:lambda` and `npm test`
- [ ] Run `flutter analyze` and `flutter test`
- [ ] Build the Flutter web app and deploy the CDK stack
- [ ] Test SOS submission, location fallback, tracker, and dispatcher ETA
- [ ] Add the public GitHub repository URL to the hackathon submission
