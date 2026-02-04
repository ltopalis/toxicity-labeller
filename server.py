from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from dotenv import load_dotenv
import psycopg2
import pandas as pd
from psycopg2.extras import Json


load_dotenv()

USER = os.getenv("user") if not None else "postgres.ywbvnvtltqhkprljimen"
PASSWORD = os.getenv(
    "password") if not None else 'rUs2FL6lMIuz19pj'
HOST = os.getenv(
    "host") if not None else 'aws-1-eu-central-1.pooler.supabase.com'
PORT = os.getenv("port") if not None else '6543'
DBNAME = os.getenv("dbname") if not None else 'postgres'

config = {
    "dbname": DBNAME,
    "user": USER,
    "password": PASSWORD,
    "host": HOST,
    "port": PORT
}

app = Flask(__name__)
CORS(app)


@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok"}


@app.route("/getSample", methods=["POST"])
def getSample():
    lang = request.json.get("lang")

    try:
        with psycopg2.connect(**config) as conn:
            with conn.cursor() as cur:
                query = "SELECT text_id, text FROM evaluation"
                if lang is not None:
                    query += " WHERE lang = %s"
                    query += " GROUP BY text_id, times_evaluated HAVING times_evaluated = MIN(times_evaluated) LIMIT 1"
                    cur.execute(query, (lang,))
                else:
                    query += " GROUP BY text_id, times_evaluated HAVING times_evaluated = MIN(times_evaluated) LIMIT 1"
                    cur.execute(query)
                row = cur.fetchone()

    except:
        pass

    return {"text_id": row[0], "text": row[1]} if row is not None else {"text_id": None, "text": None}


@app.route("/sendData", methods=["POST"])
def sendData():
    data = request.json

    try:
        with psycopg2.connect(**config) as conn:
            with conn.cursor() as cur:
                query = "SELECT update_evaluation_from_json(%s)"
                cur.execute(query, [Json(data)])
                message = cur.fetchone()
                conn.commit()
    except:
        return {"ok": False}

    return {"ok": True}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
