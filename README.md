# GenAI Support Intelligence

> An AI-powered customer support intelligence pipeline for automated ticket analysis, AI observability, and support analytics.

## Overview

GenAI Support Intelligence is a Python-based AI engineering project that processes customer support tickets using an LLM and stores structured AI insights in MySQL.

The system automatically analyzes incoming support tickets and generates:

- Support category
- Priority
- Short summary
- Confidence score

It also captures AI observability metrics such as:

- Response latency
- Input tokens
- Output tokens
- Total tokens
- Estimated API cost

The resulting data is stored in MySQL and can be analyzed using SQL to evaluate both support operations and AI model performance.

---

## Problem

Customer support systems can receive a large number of tickets across different categories.

Manually reviewing every ticket to determine its category, priority, and summary can be time-consuming.

At the same time, simply using an LLM is not enough for an engineering system.

A useful AI support system should also provide visibility into:

- How confident the AI is
- How quickly it responds
- How many tokens it consumes
- How much each request costs
- Which support categories require more attention
- Where the AI may require human intervention

This project combines AI processing with database persistence and SQL analytics to address these problems.

---

## How It Works

```text
Customer Support Ticket
          |
          v
       Python
          |
          v
       Gemini
          |
          v
Structured AI Analysis
          |
          +----------------------+
          |                      |
          v                      v
Category / Priority        Confidence / Summary
          |
          v
   AI Observability
          |
          +-----------------------------+
          |             |               |
          v             v               v
       Latency        Tokens           Cost
          |
          v
         MySQL
          |
          v
     SQL Analytics
          |
          v
    Business Insightsgit commit -m "Add SQL analysis and business insights"
