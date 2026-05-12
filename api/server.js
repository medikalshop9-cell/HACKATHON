const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Validate API key exists at startup
if (!process.env.GEMINI_API_KEY) {
  console.error('ERROR: GEMINI_API_KEY environment variable is not set.');
  process.exit(1);
}

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const FIELDS = [
  'LIMIT_BAL', 'SEX', 'EDUCATION', 'MARRIAGE', 'AGE',
  'PAY_0', 'PAY_2', 'PAY_3', 'PAY_4', 'PAY_5', 'PAY_6',
  'BILL_AMT1', 'BILL_AMT2', 'BILL_AMT3', 'BILL_AMT4', 'BILL_AMT5', 'BILL_AMT6',
  'PAY_AMT1', 'PAY_AMT2', 'PAY_AMT3', 'PAY_AMT4', 'PAY_AMT5', 'PAY_AMT6'
];

const SYSTEM_PROMPT = `You are a credit risk analyst assistant. Assess the default risk of a credit card client based on their profile.

DATASET CONTEXT:
- Taiwan credit card clients (Apr-Sep 2005), currency: New Taiwan Dollar (NTD)
- Task: estimate probability of defaulting on next month's payment

VARIABLE GUIDE:
- LIMIT_BAL: total credit limit in NTD
- PAY_0 (Sep) to PAY_6 (Apr): repayment status each month. -1=paid duly, 0=revolving credit, 1-8=months delayed
- BILL_AMT1-6: monthly statement balances in NTD
- PAY_AMT1-6: actual monthly payments in NTD
- SEX: 1=Male, 2=Female | EDUCATION: 1=Grad, 2=Uni, 3=HS, 4=Other | MARRIAGE: 1=Married, 2=Single, 3=Other

DERIVED SIGNALS (pre-computed):
- bill_to_limit_ratio: >0.8 = near credit exhaustion
- payment_coverage_ratio: <0.05 = near-zero repayment
- consecutive_delays: months with delay >= 1
- bill_trend: positive = growing debt

KEY RISK SIGNALS:
1. consecutive_delays >= 2 -> HIGH risk
2. bill_to_limit_ratio > 0.8 -> credit exhaustion
3. payment_coverage_ratio < 0.05 -> minimal repayment
4. bill_trend > 0 AND payment_coverage_ratio < 0.1 -> debt spiral
5. PAY_0 >= 2 alone -> strong signal

RISK THRESHOLDS: LOW < 0.30 | MEDIUM 0.30-0.60 | HIGH > 0.60

Return ONLY valid JSON with no markdown, no prose:
{"risk_level":"LOW","default_probability":0.18,"key_signals":["signal 1"],"recommendation":"One sentence action."}`;

// Health check
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Credit Assessment API',
    model: process.env.GEMINI_MODEL || 'gemini-1.5-flash',
    endpoint: 'GET /assess-credit?LIMIT_BAL=50000&SEX=2&EDUCATION=2&MARRIAGE=2&AGE=35&PAY_0=0&PAY_2=0&PAY_3=0&PAY_4=0&PAY_5=0&PAY_6=0&BILL_AMT1=10000&BILL_AMT2=9000&BILL_AMT3=8000&BILL_AMT4=7000&BILL_AMT5=6000&BILL_AMT6=5000&PAY_AMT1=2000&PAY_AMT2=2000&PAY_AMT3=2000&PAY_AMT4=2000&PAY_AMT5=2000&PAY_AMT6=2000'
  });
});

// Main credit assessment endpoint — supports both GET (query params) and POST (JSON body)
async function assessCredit(params, res) {
  try {
    const b = {};

    // Parse and validate all 23 fields
    for (const f of FIELDS) {
      const val = params[f];
      if (val === undefined || val === '') {
        return res.status(400).json({ error: `Missing required field: ${f}` });
      }
      const num = Number(val);
      if (isNaN(num)) {
        return res.status(400).json({ error: `Field ${f} must be a number, got: ${val}` });
      }
      b[f] = num;
    }

    // Compute derived signals
    const lim = b.LIMIT_BAL || 1;
    b.bill_to_limit_ratio = parseFloat((b.BILL_AMT1 / lim).toFixed(4));
    b.payment_coverage_ratio = b.BILL_AMT1 > 0
      ? parseFloat((b.PAY_AMT1 / b.BILL_AMT1).toFixed(4))
      : null;
    b.consecutive_delays = [b.PAY_0, b.PAY_2, b.PAY_3, b.PAY_4, b.PAY_5, b.PAY_6]
      .filter(v => v >= 1).length;
    b.bill_trend = b.BILL_AMT1 - b.BILL_AMT6;

    // Call Gemini
    const model = genAI.getGenerativeModel({
      model: process.env.GEMINI_MODEL || 'gemini-1.5-flash',
      systemInstruction: SYSTEM_PROMPT,
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 512
      }
    });

    const prompt = `Assess the default risk for this borrower and return ONLY a JSON object.\n\nBorrower Profile:\n${JSON.stringify(b, null, 2)}`;
    const result = await model.generateContent(prompt);
    const raw = result.response.text();

    // Strip markdown fences and parse JSON
    let parsed;
    try {
      const cleaned = raw.replace(/```json?\n?/gi, '').replace(/```/g, '').trim();
      const match = cleaned.match(/\{[\s\S]*\}/);
      parsed = JSON.parse(match ? match[0] : cleaned);
    } catch (e) {
      parsed = {
        risk_level: 'UNKNOWN',
        default_probability: null,
        key_signals: [`Parse error: ${e.message}`, `Raw response: ${raw.slice(0, 200)}`],
        recommendation: 'Manual review required.'
      };
    }

    // Attach derived signals to response for transparency
    parsed.derived_signals = {
      bill_to_limit_ratio: b.bill_to_limit_ratio,
      payment_coverage_ratio: b.payment_coverage_ratio,
      consecutive_delays: b.consecutive_delays,
      bill_trend: b.bill_trend
    };

    return res.json(parsed);
  } catch (err) {
    console.error('Assessment error:', err.message);
    return res.status(500).json({ error: err.message });
  }
}

app.get('/assess-credit', (req, res) => assessCredit(req.query, res));
app.post('/assess-credit', (req, res) => assessCredit(req.body, res));

app.listen(PORT, () => {
  console.log(`Credit Assessment API running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/`);
  console.log(`Assess endpoint: GET http://localhost:${PORT}/assess-credit?LIMIT_BAL=...`);
});
