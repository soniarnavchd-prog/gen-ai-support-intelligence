import os
import time
import uuid

import mysql.connector
from dotenv import load_dotenv
from google import genai
from pydantic import BaseModel


# --------------------------------------------------
# Configuration
# --------------------------------------------------

INPUT_PRICE_PER_MILLION = 0.075
OUTPUT_PRICE_PER_MILLION = 0.30

load_dotenv()


# --------------------------------------------------
# AI Response Schema
# --------------------------------------------------

class SupportAnalysis(BaseModel):
    category: str
    priority: str
    summary: str
    confidence: float


# --------------------------------------------------
# Gemini Client
# --------------------------------------------------

client = genai.Client(
    api_key=os.getenv("GEMINI_API_KEY")
)


# --------------------------------------------------
# Database Connection
# --------------------------------------------------

def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME")
    )


# --------------------------------------------------
# Process Support Ticket
# --------------------------------------------------

def process_ticket(user_id: str, customer_ticket: str):

    conversation_id = f"conv_{uuid.uuid4().hex[:12]}"
    response_id = f"resp_{uuid.uuid4().hex[:12]}"

    prompt = f"""
You are an AI customer support analyst.

Analyze the following customer support ticket.

Ticket:
{customer_ticket}

Classify the ticket into exactly one of these categories:

Shipping, Technical, Refund, Product, Login, Account, Billing.

Priority must be exactly one of:

Low, Medium, High, Critical.

Provide:
- category
- priority
- short summary
- confidence score between 0 and 1

The confidence score should represent your confidence
in the classification.
"""

    # --------------------------------------------------
    # Gemini API Call
    # --------------------------------------------------

    try:

        start_time = time.perf_counter()

        response = client.models.generate_content(
            model="gemini-3.6-flash",
            contents=prompt,
            config={
                "response_mime_type": "application/json",
                "response_schema": SupportAnalysis,
            },
        )

        end_time = time.perf_counter()

    except Exception as err:

        print("\n❌ AI processing failed")
        print("Error:", err)

        return False


    # --------------------------------------------------
    # AI Result
    # --------------------------------------------------

    response_time_ms = (end_time - start_time) * 1000

    result = response.parsed

    if result is None:
        print("\n❌ AI returned no structured result")
        return False


    # --------------------------------------------------
    # Token Usage
    # --------------------------------------------------

    usage = response.usage_metadata

    input_tokens = usage.prompt_token_count or 0
    output_tokens = usage.candidates_token_count or 0
    total_tokens = usage.total_token_count or 0


    # --------------------------------------------------
    # Cost Calculation
    # --------------------------------------------------

    input_cost = (
        input_tokens / 1_000_000
    ) * INPUT_PRICE_PER_MILLION

    output_cost = (
        output_tokens / 1_000_000
    ) * OUTPUT_PRICE_PER_MILLION

    total_cost = input_cost + output_cost


    # --------------------------------------------------
    # Database Operations
    # --------------------------------------------------

    db = None
    cursor = None

    try:

        db = get_db_connection()
        cursor = db.cursor()

        # Insert conversation
        conversation_query = """
        INSERT INTO conversations
        (
            conversation_id,
            user_id,
            category,
            priority,
            status
        )
        VALUES (%s, %s, %s, %s, %s)
        """

        cursor.execute(
            conversation_query,
            (
                conversation_id,
                user_id,
                result.category,
                result.priority,
                "open"
            )
        )


        # Insert AI response
        response_query = """
        INSERT INTO ai_responses
        (
            response_id,
            conversation_id,
            model_name,
            response_time_ms,
            tokens_used,
            confidence_score,
            customer_text,
            summary,
            input_tokens,
            output_tokens,
            cost_usd
        )
        VALUES
        (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        cursor.execute(
            response_query,
            (
                response_id,
                conversation_id,
                "gemini-3.6-flash",
                round(response_time_ms),
                total_tokens,
                result.confidence,
                customer_ticket.strip(),
                result.summary,
                input_tokens,
                output_tokens,
                total_cost
            )
        )


        # Commit only after both inserts succeed
        db.commit()


    except mysql.connector.Error as err:

        if db:
            db.rollback()

        print("\n❌ Database operation failed")
        print("Error:", err)

        return False


    finally:

        if cursor:
            cursor.close()

        if db:
            db.close()


    # --------------------------------------------------
    # Output
    # --------------------------------------------------

    print("\n✅ Ticket processed")
    print("-------------------------")
    print("Conversation :", conversation_id)
    print("Category     :", result.category)
    print("Priority     :", result.priority)
    print("Summary      :", result.summary)
    print("Confidence   :", result.confidence)
    print("Latency      :", round(response_time_ms, 2), "ms")
    print("Input Tokens :", input_tokens)
    print("Output Tokens:", output_tokens)
    print("Total Tokens :", total_tokens)
    print("Total Cost   : $", round(total_cost, 8))

    return True


# --------------------------------------------------
# Example Ticket
# --------------------------------------------------

if __name__ == "__main__":

    process_ticket(
        user_id="U0555",
        customer_ticket=(
            "My package is three days late "
            "and the tracking has not updated."
        )
    )