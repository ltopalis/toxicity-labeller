require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  ssl: { rejectUnauthorized: false },
});

app.get("/health", (_, res) => {
  res.json({ status: "ok" });
});

app.post("/getSample", async (req, res) => {
  const { lang } = req.body;

  try {
    let query;
    let values = [];

    if (lang && lang !== "null") {
      query =
        "SELECT text_id, text FROM evaluation WHERE lang = $1 ORDER BY times_evaluated ASC, RANDOM() LIMIT 1";
      values = [lang];
    } else {
      query =
        "SELECT text_id, text FROM evaluation ORDER BY times_evaluated ASC, RANDOM() LIMIT 1";
    }

    const result = await pool.query(query, values);

    if (result.rows.length > 0) {
      res.json({ text_id: result.rows[0].text_id, text: result.rows[0].text });
    } else {
      res.json({ text_id: null, text: null });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/sendData", async (req, res) => {
  const data = req.body;
  try {
    // Στο pg το $1 δέχεται αντικείμενο JSON απευθείας
    const query = "SELECT update_evaluation_from_json($1)";
    const result = await pool.query(query, [JSON.stringify(data)]);

    res.json({ ok: true, message: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.json({ ok: false });
  }
});

app.listen(3000, "0.0.0.0", () => {
  console.log("Server is running on http://0.0.0.0:3000");
});

setInterval(
  async () => {
    try {
      const response = await fetch(
        "https://toxicity-backend.onrender.com/health",
      );
      const data = await response.json();
    } catch (error) {
      console.error("Health check failed:", error);
    }
  },
  3 * 60 * 1000,
);
