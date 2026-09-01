import os
import time
import uuid

import mysql.connector
from dotenv import load_dotenv
from google import genai
from pydantic import BaseModel


# ============================================================
# 1. CONFIGURATION
# ============================================================

# Pricing assumptions per 1 million tokens
INPUT_PRICE_PER_MILLION = 0.075
OUTPUT_PRICE_PER_MILLION = 0.30

# Load variables from .env
load_dotenv()


# ============================================================
# 2. DATABASE CONNECTION
# ============================================================

def get_database_connection():
    """
    Creates and returns a MySQL database connection.

    Credentials are loaded from environment variables
    instead of being hardcoded in the source code.
    """

    return mysql.connector.connect(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME")
    )


# ============================================================
# 3. AI OUTPUT SCHEMA
# ============================================================

class SupportAnalysis(BaseModel):
    """
    Defines the structure expected from Gemini.
    """

    category: str
    priority: str
    summary: str
    confidence: float


# ============================================================
# 4. GEMINI CLIENT
# ============================================================

client = genai.Client(
    api_key=os.getenv("GEMINI_API_KEY")
)


# ============================================================
# 5. SAMPLE INPUT DATA
# ============================================================
# These tickets are only demonstration/test inputs.
# In a real application, tickets could come from an API,
# frontend, message queue, CRM, etc.

tickets = [
    {
        "user_id": "U0555",
        "text": "My package is three days late and the tracking has not updated."
    },
    {
        "user_id": "U0622",
        "text": "I was charged twice for the same purchase and need a refund."
    },
    {
        "user_id": "U0784",
        "text": "I cannot log into my account even though I reset my password."
    },
    {
        "user_id": "U0312",
        "text": "The product I received is damaged and I want to return it."
    },
    {
        "user_id": "U0560",
        "text": "The application crashes every time I try to upload a document."
    }
]


# ============================================================
# 6. PROCESS ONE CUSTOMER TICKET
# ============================================================

def process_ticket(db, user_id, customer_ticket):

    # --------------------------------------------------------
    # Generate unique IDs for database records
    # --------------------------------------------------------

    conversation_id = f"conv_{uuid.uuid4().hex[:12]}"
    response_id = f"resp_{uuid.uuid4().hex[:12]}"


    # --------------------------------------------------------
    # Build the LLM prompt
    # --------------------------------------------------------

    prompt = f"""
    You are an AI customer support analyst.

    Analyze the following customer support ticket.

    Ticket:
    {customer_ticket}

    Classify the ticket into these categories:
    Shipping, Technical, Refund, Product, Login, Account, Billing.

    Priority must be one of:
    Low, Medium, High, Critical.

    Provide:
    - category
    - priority
    - a short summary
    - confidence score between 0 and 1

    The confidence score should represent how confident you are
    in your classification.
    """


    # --------------------------------------------------------
    # Measure actual Gemini API latency
    # --------------------------------------------------------

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


    # --------------------------------------------------------
    # Calculate response latency
    # --------------------------------------------------------

    response_time_ms = (end_time - start_time) * 1000


    # --------------------------------------------------------
    # Extract structured AI result
    # --------------------------------------------------------

    result = response.parsed


    # --------------------------------------------------------
    # Extract token usage
    # --------------------------------------------------------

    usage = response.usage_metadata

    input_tokens = usage.prompt_token_count
    output_tokens = usage.candidates_token_count
    total_tokens = usage.total_token_count


    # --------------------------------------------------------
    # Calculate estimated AI cost
    # --------------------------------------------------------

    input_cost = (
        input_tokens / 1_000_000
    ) * INPUT_PRICE_PER_MILLION

    output_cost = (
        output_tokens / 1_000_000
    ) * OUTPUT_PRICE_PER_MILLION

    total_cost = input_cost + output_cost


    # ========================================================
    # 7. DATABASE OPERATIONS
    # ========================================================

    cursor = db.cursor()

    try:

        # ----------------------------------------------------
        # Insert conversation into conversations table
        # ----------------------------------------------------

        conversation_query = """
        INSERT INTO conversations
        (
            conversation_id,
            user_id,
            category,
            priority,
            status,
            created_at
        )
        VALUES
        (
            %s,
            %s,
            %s,
            %s,
            %s,
            NOW()
        )
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


        # ----------------------------------------------------
        # Insert AI metrics into ai_responses table
        # ----------------------------------------------------

        response_query = """
        INSERT INTO ai_responses
        (
            response_id,
            conversation_id,
            model_name,
            response_time_ms,
            tokens_used,
            confidence_score,
            response_at,
            customer_text,
            input_tokens,
            output_tokens,
            cost_usd,
            summary
        )
        VALUES
        (
            %s,
            %s,
            %s,
            %s,
            %s,
            %s,
            NOW(),
            %s,
            %s,
            %s,
            %s,
            %s
        )
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
                input_tokens,
                output_tokens,
                total_cost,
                result.summary
            )
        )


        # ----------------------------------------------------
        # Commit transaction
        # ----------------------------------------------------

        db.commit()


        # ====================================================
        # 8. DISPLAY RESULT
        # ====================================================

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
        print("Cost         : $", round(total_cost, 8))


    # ========================================================
    # 9. DATABASE ERROR HANDLING
    # ========================================================

    except mysql.connector.Error as err:

        # Undo database changes if something fails
        db.rollback()

        print("\n❌ Database error")
        print(err)

        raise

    finally:

        # Always close cursor
        cursor.close()


# ============================================================
# 10. MAIN PROGRAM
# ============================================================

def main():

    db = None

    try:

        # ----------------------------------------------------
        # Establish MySQL connection
        # ----------------------------------------------------

        db = get_database_connection()

        print("✅ MySQL connection successful!")


        # ----------------------------------------------------
        # Process every ticket
        # ----------------------------------------------------

        for ticket in tickets:

            process_ticket(
                db,
                ticket["user_id"],
                ticket["text"]
            )


    except mysql.connector.Error as err:

        print("❌ Could not connect to MySQL")
        print(err)


    finally:

        # ----------------------------------------------------
        # Close database connection
        # ----------------------------------------------------

        if db is not None and db.is_connected():
            db.close()

            print("\n🔒 MySQL connection closed.")


# ============================================================
# 11. PROGRAM ENTRY POINT
# ============================================================

if __name__ == "__main__":
    main()
