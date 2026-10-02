# AegisMind — AI-Powered Emergency SOS Triage System

AegisMind is an intelligent emergency response platform designed to automate distress message classification during natural disasters, critical accidents, and large-scale emergency situations. By converting raw, unstructured distress reports into structured, prioritized incident data, AegisMind enables emergency dispatchers to allocate life-saving resources within seconds.

---

## The Problem
During crisis events (e.g., floods, earthquakes, or mass casualties), emergency command centers receive thousands of incoming SOS messages per minute across SMS, mobile apps, and web interfaces. Traditional dispatch systems rely on human operators to manually read, categorize, and prioritize each report. This manual bottleneck causes delayed response times for life-threatening situations where seconds matter.

---

## The Solution
AegisMind provides an automated serverless pipeline that ingests raw distress reports, evaluates incident severity using an AI Triage Engine, and instantly updates a centralized First Responder Dispatch Dashboard. 

```text
[ Citizen Distress SOS ] 
           │
           ▼
[ AWS API Gateway Endpoint ]
           │
           ▼
[ AWS Lambda Triage Engine ] ◄──► [ Generative AI Model ]
           │
           ▼
[ AWS DynamoDB Incident Store ]
           │
           ▼
[ Flutter Dispatch Command Dashboard ]

---

## Local configuration

This repository deliberately does not contain credentials. Copy `.env.example`
to `.env` and set `GEMINI_API_KEY` locally before deploying the AWS CDK stack.
Never commit `.env`, AWS credentials, private keys, build folders, or CDK
asset output.

The application source is in:

- `aegismind_frontend/` — Flutter web/mobile UI
- `aegismind-backend/` — AWS CDK infrastructure and Lambda triage engine
