-- ============================================================
-- GENAI SUPPORT INTELLIGENCE
-- BUSINESS & AI ENGINEERING INSIGHTS
-- ============================================================

USE gen_ai_support_intelligence;


-- ============================================================
-- 1. CATEGORY PERFORMANCE
-- ============================================================

-- Identify support categories with high volume,
-- low AI confidence, and slow response times.

WITH category_kpis AS (
    SELECT
        c.category,

        COUNT(DISTINCT c.conversation_id)
            AS total_conversations,

        COUNT(DISTINCT CASE
            WHEN c.status = 'Escalated'
            THEN c.conversation_id
        END) AS escalated_conversations,

        ROUND(
            COUNT(DISTINCT CASE
                WHEN c.status = 'Escalated'
                THEN c.conversation_id
            END) * 100.0
            / NULLIF(COUNT(DISTINCT c.conversation_id), 0),
            2
        ) AS escalation_rate,

        ROUND(AVG(a.confidence_score), 4)
            AS avg_ai_confidence,

        ROUND(AVG(a.response_time_ms), 2)
            AS avg_response_time

    FROM conversations c

    LEFT JOIN ai_responses a
        ON c.conversation_id = a.conversation_id

    GROUP BY c.category
)

SELECT *
FROM category_kpis
ORDER BY escalation_rate DESC;


-- ============================================================
-- 2. AI MODEL PERFORMANCE
-- ============================================================

-- Compare models across confidence, latency,
-- token consumption, and estimated cost.

SELECT
    model_name,

    COUNT(*) AS total_responses,

    ROUND(AVG(confidence_score), 4)
        AS avg_confidence,

    ROUND(AVG(response_time_ms), 2)
        AS avg_response_time_ms,

    SUM(tokens_used)
        AS total_tokens,

    ROUND(AVG(tokens_used), 2)
        AS avg_tokens_per_response,

    ROUND(SUM(cost_usd), 8)
        AS total_estimated_cost,

    ROUND(AVG(cost_usd), 8)
        AS avg_cost_per_response

FROM ai_responses

GROUP BY model_name

ORDER BY avg_confidence DESC;


-- ============================================================
-- 3. LOW-CONFIDENCE AI RESPONSES
-- ============================================================

-- Identify responses where the AI may need
-- additional validation or human review.

SELECT
    a.response_id,
    a.conversation_id,
    c.category,
    c.priority,
    a.model_name,
    a.confidence_score,
    a.response_time_ms,
    a.customer_text,
    a.summary

FROM ai_responses a

JOIN conversations c
    ON a.conversation_id = c.conversation_id

WHERE a.confidence_score < 0.60

ORDER BY a.confidence_score ASC;


-- ============================================================
-- 4. AI PROBLEM ZONES
-- ============================================================

-- Find categories where the AI is both
-- relatively slow and less confident.

WITH category_metrics AS (
    SELECT
        c.category,

        ROUND(AVG(a.confidence_score), 4)
            AS avg_confidence,

        ROUND(AVG(a.response_time_ms), 2)
            AS avg_response_time

    FROM conversations c

    JOIN ai_responses a
        ON c.conversation_id = a.conversation_id

    GROUP BY c.category
)

SELECT
    category,
    avg_confidence,
    avg_response_time

FROM category_metrics

WHERE avg_confidence < 0.70
  AND avg_response_time > 2000

ORDER BY avg_confidence ASC;


-- ============================================================
-- 5. ESCALATION ANALYSIS
-- ============================================================

-- Determine which categories require the most
-- human intervention.

SELECT
    category,

    COUNT(*) AS total_conversations,

    SUM(
        CASE
            WHEN status = 'Escalated'
            THEN 1
            ELSE 0
        END
    ) AS escalated_conversations,

    ROUND(
        SUM(
            CASE
                WHEN status = 'Escalated'
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS escalation_rate

FROM conversations

GROUP BY category

ORDER BY escalation_rate DESC;


-- ============================================================
-- 6. CONFIDENCE DISTRIBUTION
-- ============================================================

-- Understand how frequently the AI produces
-- low, medium, and high confidence predictions.

WITH confidence_groups AS (
    SELECT
        CASE
            WHEN confidence_score < 0.60
                THEN 'Low Confidence'

            WHEN confidence_score < 0.80
                THEN 'Medium Confidence'

            ELSE 'High Confidence'
        END AS confidence_category

    FROM ai_responses
)

SELECT
    confidence_category,

    COUNT(*) AS total_responses,

    ROUND(
        COUNT(*) * 100.0
        / (SELECT COUNT(*) FROM ai_responses),
        2
    ) AS percentage

FROM confidence_groups

GROUP BY confidence_category

ORDER BY total_responses DESC;


-- ============================================================
-- 7. RESPONSE SPEED
-- ============================================================

-- Analyze AI response latency.

SELECT
    CASE
        WHEN response_time_ms < 1000
            THEN 'Fast'

        WHEN response_time_ms < 2000
            THEN 'Normal'

        ELSE 'Slow'
    END AS speed_category,

    COUNT(*) AS total_responses,

    ROUND(AVG(response_time_ms), 2)
        AS avg_response_time_ms

FROM ai_responses

GROUP BY speed_category

ORDER BY avg_response_time_ms ASC;


-- ============================================================
-- 8. CUSTOMER PLAN VS AI CONFIDENCE
-- ============================================================

-- Determine whether AI confidence differs
-- across customer subscription plans.

SELECT
    u.plan,

    COUNT(a.response_id)
        AS total_ai_responses,

    ROUND(AVG(a.confidence_score), 4)
        AS avg_ai_confidence,

    ROUND(AVG(a.response_time_ms), 2)
        AS avg_response_time

FROM users u

JOIN conversations c
    ON u.user_id = c.user_id

JOIN ai_responses a
    ON c.conversation_id = a.conversation_id

GROUP BY u.plan

ORDER BY avg_ai_confidence DESC;


-- ============================================================
-- 9. CUSTOMER FEEDBACK VS AI PERFORMANCE
-- ============================================================

-- Compare customer ratings with AI performance.

SELECT
    a.model_name,

    COUNT(f.feedback_id)
        AS feedback_count,

    ROUND(AVG(f.rating), 2)
        AS avg_customer_rating,

    ROUND(AVG(a.confidence_score), 4)
        AS avg_ai_confidence,

    ROUND(AVG(a.response_time_ms), 2)
        AS avg_response_time

FROM ai_responses a

JOIN feedback f
    ON a.conversation_id = f.conversation_id

GROUP BY a.model_name

ORDER BY avg_customer_rating DESC;


-- ============================================================
-- 10. OVERALL AI SYSTEM KPI
-- ============================================================

-- High-level health metrics for the AI support system.

SELECT

    COUNT(*) AS total_ai_responses,

    ROUND(AVG(confidence_score), 4)
        AS overall_avg_confidence,

    ROUND(AVG(response_time_ms), 2)
        AS overall_avg_latency_ms,

    SUM(tokens_used)
        AS total_tokens_used,

    ROUND(SUM(cost_usd), 8)
        AS total_estimated_cost,

    SUM(
        CASE
            WHEN confidence_score < 0.60
            THEN 1
            ELSE 0
        END
    ) AS low_confidence_responses,

    ROUND(
        SUM(
            CASE
                WHEN confidence_score < 0.60
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS low_confidence_rate

FROM ai_responses;