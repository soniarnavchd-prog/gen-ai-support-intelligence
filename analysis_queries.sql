-- ============================================================
-- GENAI SUPPORT INTELLIGENCE
-- SQL ANALYSIS QUERIES
-- ============================================================

USE gen_ai_support_intelligence;


-- ============================================================
-- 1. BASIC DATA EXPLORATION
-- ============================================================

-- View users
SELECT *
FROM users;


-- View conversations
SELECT *
FROM conversations;


-- View AI responses
SELECT *
FROM ai_responses;


-- View feedback
SELECT *
FROM feedback;


-- View escalations
SELECT *
FROM escalations;


-- ============================================================
-- 2. FILTERING
-- ============================================================

-- Escalated conversations
SELECT *
FROM conversations
WHERE status = 'Escalated';


-- Critical priority conversations
SELECT *
FROM conversations
WHERE priority = 'Critical';


-- Low-confidence AI responses
SELECT *
FROM ai_responses
WHERE confidence_score < 0.60;


-- Slowest AI responses
SELECT *
FROM ai_responses
ORDER BY response_time_ms DESC
LIMIT 10;


-- Highest-rated feedback
SELECT *
FROM feedback
WHERE rating = 5;


-- Open conversations
SELECT *
FROM conversations
WHERE status = 'open';


-- ============================================================
-- 3. GROUP BY / AGGREGATION
-- ============================================================

-- Conversations by category
SELECT
    category,
    COUNT(*) AS total_conversations
FROM conversations
GROUP BY category
ORDER BY total_conversations DESC;


-- Conversations by status
SELECT
    status,
    COUNT(*) AS total_conversations
FROM conversations
GROUP BY status
ORDER BY total_conversations DESC;


-- Conversations by priority
SELECT
    priority,
    COUNT(*) AS total_conversations
FROM conversations
GROUP BY priority
ORDER BY total_conversations DESC;


-- Users by country
SELECT
    country,
    COUNT(*) AS total_users
FROM users
GROUP BY country
ORDER BY total_users DESC;


-- Users by subscription plan
SELECT
    plan,
    COUNT(*) AS total_users
FROM users
GROUP BY plan
ORDER BY total_users DESC;


-- Average response time by model
SELECT
    model_name,
    ROUND(AVG(response_time_ms), 2) AS avg_response_time
FROM ai_responses
GROUP BY model_name
ORDER BY avg_response_time ASC;


-- Average confidence by model
SELECT
    model_name,
    ROUND(AVG(confidence_score), 4) AS avg_confidence
FROM ai_responses
GROUP BY model_name
ORDER BY avg_confidence DESC;


-- Total tokens consumed by model
SELECT
    model_name,
    SUM(tokens_used) AS total_tokens
FROM ai_responses
GROUP BY model_name
ORDER BY total_tokens DESC;


-- Average customer rating by feedback type
SELECT
    feedback_type,
    ROUND(AVG(rating), 2) AS avg_rating
FROM feedback
GROUP BY feedback_type
ORDER BY avg_rating DESC;


-- Escalations by category
SELECT
    category,
    COUNT(*) AS total_escalations
FROM conversations
WHERE status = 'Escalated'
GROUP BY category
ORDER BY total_escalations DESC;


-- ============================================================
-- 4. JOINS
-- ============================================================

-- Users and their conversations
SELECT
    u.user_id,
    u.name,
    c.conversation_id,
    c.category,
    c.status
FROM users u
JOIN conversations c
    ON u.user_id = c.user_id;


-- User country and conversation category
SELECT
    u.name,
    u.country,
    c.category
FROM users u
JOIN conversations c
    ON u.user_id = c.user_id;


-- Escalated conversations with customer information
SELECT
    u.name,
    c.conversation_id,
    c.category
FROM users u
JOIN conversations c
    ON u.user_id = c.user_id
WHERE c.status = 'Escalated';


-- AI responses with conversation information
SELECT
    c.conversation_id,
    c.category,
    a.model_name,
    a.response_time_ms,
    a.confidence_score
FROM conversations c
JOIN ai_responses a
    ON c.conversation_id = a.conversation_id;


-- Slow AI responses
SELECT
    c.conversation_id,
    c.category,
    a.model_name,
    a.response_time_ms
FROM conversations c
JOIN ai_responses a
    ON c.conversation_id = a.conversation_id
WHERE a.response_time_ms > 2500;


-- Average AI response time by category
SELECT
    c.category,
    ROUND(AVG(a.response_time_ms), 2) AS avg_response_time
FROM conversations c
JOIN ai_responses a
    ON c.conversation_id = a.conversation_id
GROUP BY c.category
ORDER BY avg_response_time DESC;


-- Model performance by conversation status
SELECT
    a.model_name,
    c.status,
    COUNT(a.response_id) AS total_responses
FROM conversations c
JOIN ai_responses a
    ON c.conversation_id = a.conversation_id
GROUP BY a.model_name, c.status
ORDER BY a.model_name, total_responses DESC;


-- Customer feedback with user information
SELECT
    u.name,
    u.country,
    f.rating,
    f.feedback_type
FROM users u
JOIN conversations c
    ON u.user_id = c.user_id
JOIN feedback f
    ON c.conversation_id = f.conversation_id;


-- Average rating by AI model
SELECT
    a.model_name,
    ROUND(AVG(f.rating), 2) AS avg_rating
FROM ai_responses a
JOIN feedback f
    ON a.conversation_id = f.conversation_id
GROUP BY a.model_name
ORDER BY avg_rating DESC;


-- Average AI confidence by customer plan
SELECT
    u.plan,
    ROUND(AVG(a.confidence_score), 4) AS avg_confidence
FROM users u
JOIN conversations c
    ON u.user_id = c.user_id
JOIN ai_responses a
    ON c.conversation_id = a.conversation_id
GROUP BY u.plan
ORDER BY avg_confidence DESC;


-- ============================================================
-- 5. CASE EXPRESSIONS
-- ============================================================

-- AI confidence classification
SELECT
    response_id,
    confidence_score,
    CASE
        WHEN confidence_score < 0.60 THEN 'Low'
        WHEN confidence_score >= 0.80 THEN 'High'
        ELSE 'Medium'
    END AS confidence_level
FROM ai_responses;


-- Response speed classification
SELECT
    response_id,
    response_time_ms,
    CASE
        WHEN response_time_ms < 1000 THEN 'Fast'
        WHEN response_time_ms < 2000 THEN 'Normal'
        ELSE 'Slow'
    END AS speed_category
FROM ai_responses;


-- Priority level
SELECT
    conversation_id,
    priority,
    CASE
        WHEN priority = 'Low' THEN 1
        WHEN priority = 'Medium' THEN 2
        WHEN priority = 'High' THEN 3
        WHEN priority = 'Critical' THEN 4
    END AS priority_level
FROM conversations;


-- Customer plan classification
SELECT
    user_id,
    plan,
    CASE
        WHEN plan IN ('Free', 'Basic') THEN 'Basic'
        ELSE 'Premium'
    END AS plan_type
FROM users;


-- Feedback classification
SELECT
    feedback_id,
    rating,
    CASE
        WHEN rating <= 2 THEN 'Poor'
        WHEN rating = 3 THEN 'Average'
        ELSE 'Good'
    END AS rating_category
FROM feedback;


-- ============================================================
-- 6. CTEs
-- ============================================================

-- Models consuming above-average tokens
WITH model_tokens AS (
    SELECT
        model_name,
        SUM(tokens_used) AS total_tokens
    FROM ai_responses
    GROUP BY model_name
)
SELECT
    model_name,
    total_tokens
FROM model_tokens
WHERE total_tokens > (
    SELECT AVG(total_tokens)
    FROM model_tokens
);


-- Model performance
WITH model_performance AS (
    SELECT
        model_name,
        ROUND(AVG(confidence_score), 4) AS avg_confidence,
        ROUND(AVG(response_time_ms), 2) AS avg_response_time,
        SUM(tokens_used) AS total_tokens
    FROM ai_responses
    GROUP BY model_name
)
SELECT
    model_name,
    avg_confidence,
    avg_response_time,
    total_tokens
FROM model_performance
ORDER BY avg_confidence DESC;


-- Low-confidence and slow responses
WITH ai_metrics AS (
    SELECT
        conversation_id,
        model_name,
        confidence_score,
        response_time_ms
    FROM ai_responses
)
SELECT
    conversation_id,
    model_name,
    confidence_score,
    response_time_ms
FROM ai_metrics
WHERE confidence_score < 0.60
  AND response_time_ms > 2000;


-- Category performance
WITH category_metrics AS (
    SELECT
        c.category,
        ROUND(AVG(a.confidence_score), 4) AS avg_confidence,
        ROUND(AVG(a.response_time_ms), 2) AS avg_response_time,
        COUNT(a.response_id) AS total_responses
    FROM conversations c
    JOIN ai_responses a
        ON c.conversation_id = a.conversation_id
    GROUP BY c.category
)
SELECT
    category,
    avg_confidence,
    avg_response_time,
    total_responses
FROM category_metrics
ORDER BY total_responses DESC;


-- Escalation analysis
WITH category_summary AS (
    SELECT
        category,
        COUNT(*) AS total_conversations,
        COUNT(
            CASE
                WHEN status = 'Escalated' THEN 1
            END
        ) AS escalated_conversations
    FROM conversations
    GROUP BY category
)
SELECT
    category,
    total_conversations,
    escalated_conversations
FROM category_summary
ORDER BY total_conversations DESC;


-- Escalation rate
WITH escalation_rates AS (
    SELECT
        category,
        COUNT(*) AS total_conversations,
        SUM(status = 'Escalated') AS escalated_conversations,
        ROUND(
            SUM(status = 'Escalated') * 100.0 / COUNT(*),
            2
        ) AS escalation_rate
    FROM conversations
    GROUP BY category
)
SELECT
    category,
    total_conversations,
    escalated_conversations,
    escalation_rate
FROM escalation_rates
ORDER BY escalation_rate DESC;


-- Low-confidence rate by model
WITH low_confidence AS (
    SELECT
        model_name,
        COUNT(*) AS total_responses,
        SUM(
            CASE
                WHEN confidence_score < 0.60 THEN 1
                ELSE 0
            END
        ) AS low_confidence_responses
    FROM ai_responses
    GROUP BY model_name
)
SELECT
    model_name,
    total_responses,
    low_confidence_responses,
    ROUND(
        low_confidence_responses * 100.0 / total_responses,
        2
    ) AS low_confidence_rate
FROM low_confidence
ORDER BY low_confidence_rate DESC;


-- ============================================================
-- 7. WINDOW FUNCTIONS
-- ============================================================

-- Rank models by average confidence
SELECT
    model_name,
    ROUND(AVG(confidence_score), 4) AS avg_confidence,
    RANK() OVER (
        ORDER BY AVG(confidence_score) DESC
    ) AS confidence_rank
FROM ai_responses
GROUP BY model_name;


-- Rank categories by average response time
SELECT
    c.category,
    ROUND(AVG(a.response_time_ms), 2) AS avg_response_time,
    RANK() OVER (
        ORDER BY AVG(a.response_time_ms)
    ) AS speed_rank
FROM conversations c
JOIN ai_responses a
    ON c.conversation_id = a.conversation_id
GROUP BY c.category;


-- Compare model confidence against overall average
SELECT
    model_name,
    ROUND(AVG(confidence_score), 4) AS avg_confidence,
    ROUND(
        AVG(confidence_score)
        - AVG(AVG(confidence_score)) OVER (),
        4
    ) AS difference_from_overall_avg
FROM ai_responses
GROUP BY model_name;


-- Running token usage by response
SELECT
    response_id,
    response_at,
    tokens_used,
    SUM(tokens_used) OVER (
        ORDER BY response_at, response_id
    ) AS running_tokens
FROM ai_responses;


-- Model response ranking
SELECT
    response_id,
    model_name,
    confidence_score,
    RANK() OVER (
        PARTITION BY model_name
        ORDER BY confidence_score DESC
    ) AS model_confidence_rank
FROM ai_responses;