import express from "express";
import cookieParser from "cookie-parser";
import { createServer as createViteServer } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(cookieParser());
  app.use(express.json());

  // API Routes
  app.get("/api/health", (req, res) => {
    res.json({ status: "ok", message: "GiftJoy API is running" });
  });

  // Mock Payment Intent
  app.post("/api/create-payment-intent", (req, res) => {
    const { amount } = req.body;
    res.json({
      clientSecret: `mock_secret_${Math.random().toString(36).substring(7)}`,
      amount
    });
  });

  // Mock Shipping Tracker
  app.get("/api/track/:id", (req, res) => {
    const statuses = ["Order Placed", "Packaging", "In Transit", "Out for Delivery", "Delivered"];
    const status = statuses[Math.floor(Math.random() * statuses.length)];
    res.json({
      trackingId: req.params.id,
      status,
      lastUpdated: new Date().toISOString()
    });
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
