require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const format = require("pg-format");

const allowedOrigins = [
  "http://localhost:3000/",
  "https://cosmic-kelpie-b639a3.netlify.app/",
];

const app = express();
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));
app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin || allowedOrigins.indexOf(origin) !== -1) {
        callback(null, true);
      } else {
        callback(new Error("Not allowed by CORS"));
      }
    },
  }),
);

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

const getToxicityJSON = (val) => {
  const base = { neutral: 0, implicit: 0, explicit: 0 };
  const key = val?.toLowerCase().trim();
  if (base.hasOwnProperty(key)) base[key] = 3;
  return JSON.stringify(base);
};

const getTargetJSON = (val) => {
  const base = { Group: 0, None: 0, Individual: 0, Other: 0 };
  const key = val
    ? val.charAt(0).toUpperCase() + val.slice(1).toLowerCase().trim()
    : "None";
  if (base.hasOwnProperty(key)) {
    base[key] = 3;
  } else {
    base["None"] = 3;
  }
  return JSON.stringify(base);
};

const getBiasJSON = (val) => {
  const base = {
    "Appearance / Physical Bias": 0,
    "Cognitive / Intelligence bias": 0,
    "Gender / Identity bias": 0,
    "Institutional / Media Bias": 0,
    "Migration /  Ethnic Bias": 0,
    None: 0,
    "Political / Ideological Bias": 0,
    "Religious Bias": 0,
    "Socioeconomic / Educational Bias": 0,
  };
  if (base.hasOwnProperty(val)) {
    base[val] = 3;
  } else {
    base["None"] = 3;
  }
  return JSON.stringify(base);
};

app.post("/upload-data", async (req, res) => {
  const data = req.body;
  console.log("hi");

  console.log(data);

  try {
    const values = data.map((row) => [
      row.text_id,
      row.text,
      row.lang,
      getToxicityJSON(row.toxicity),
      getTargetJSON(row.target_type),
      getBiasJSON(row.bias_type),
    ]);

    const sql = format(
      "INSERT INTO evaluation (text_id, text, lang, toxicity, target_type, bias_type) VALUES %L ON CONFLICT (text_id) DO NOTHING",
      values,
    );

    await pool.query(sql);
    res.status(200).json({ message: `Done! Processed ${data.length} rows.` });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
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
