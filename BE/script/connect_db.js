const { Client } = require("pg");

// Database configuration
const config = {
  host: "14.225.212.86",
  port: 5432,
  database: "cuchum_db",
  user: "cuchum_admin",
  password: "Tsnn@123",
};

// Create PostgreSQL client
const client = new Client(config);

async function connectDB() {
  try {
    // Connect to database
    await client.connect();
    console.log("✅ Connected to PostgreSQL database successfully!");
    console.log(`📊 Database: ${config.database}`);
    console.log(`🖥️  Host: ${config.host}`);

    // Test query
    const result = await client.query("SELECT NOW(), version()");
    console.log("\n📅 Server time:", result.rows[0].now);
    console.log("📌 PostgreSQL version:", result.rows[0].version);

    // Keep connection open for interactive use
    // You can add your queries here or use REPL
    console.log("\n💡 Connection is open. Press Ctrl+C to exit.");
  } catch (error) {
    console.error("❌ Connection error:", error.message);
    process.exit(1);
  }
}

// Handle Ctrl+C gracefully
process.on("SIGINT", async () => {
  console.log("\n\n👋 Closing connection...");
  await client.end();
  console.log("✅ Connection closed.");
  process.exit(0);
});

// Start connection
connectDB();
