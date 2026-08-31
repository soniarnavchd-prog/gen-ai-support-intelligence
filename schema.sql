-- ============================================================
-- GenAI Support Intelligence
-- Database Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS gen_ai_support_intelligence;

USE gen_ai_support_intelligence;


-- ============================================================
-- 1. USERS
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    user_id TEXT,
    name TEXT,
    plan TEXT,
    country TEXT,
    signup_date TEXT
);


-- ============================================================
-- 2. CONVERSATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS conversations (
    conversation_id TEXT,
    user_id TEXT,
    category TEXT,
    priority TEXT,
    created_at TEXT,
    resolved_at TEXT,
    status TEXT
);


-- ============================================================
-- 3. AI RESPONSES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_responses (
    response_id TEXT,
    conversation_id TEXT,
    model_name TEXT,
    response_time_ms INT DEFAULT NULL,
    tokens_used INT DEFAULT NULL,
    confidence_score DOUBLE DEFAULT NULL,
    response_at TEXT,
    customer_text TEXT,
    input_tokens INT DEFAULT NULL,
    output_tokens INT DEFAULT NULL,
    cost_usd DECIMAL(10,8) DEFAULT NULL,
    summary TEXT
);


-- ============================================================
-- 4. FEEDBACK
-- ============================================================

CREATE TABLE IF NOT EXISTS feedback (
    feedback_id TEXT,
    conversation_id TEXT,
    rating INT DEFAULT NULL,
    feedback_type TEXT,
    created_at TEXT
);


-- ============================================================
-- 5. ESCALATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS escalations (
    escalation_id TEXT,
    conversation_id TEXT,
    reason TEXT,
    agent_id TEXT,
    escalated_at TEXT,
    resolved_at TEXT
);